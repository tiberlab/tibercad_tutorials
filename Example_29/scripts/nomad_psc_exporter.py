#!/usr/bin/env python3
"""
NOMAD Perovskite Solar Cell Data Exporter
=========================================
Queries the NOMAD Repository API (https://nomad-lab.eu/prod/v1/api/v1)
for PerovskiteSolarCell entries that contain populated data for both:
  1. Encapsulation (data.encapsulation)
  2. Stability (data.stability, data.operational_stability, etc.)

Exports matching dataset into JSON, CSV, and Excel formats.
"""

import argparse
import csv
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Tuple, Union

try:
    import requests
except ImportError:
    requests = None

try:
    import urllib.request
    import urllib.error
except ImportError:
    urllib = None

try:
    import pandas as pd
except ImportError:
    pd = None

try:
    from tqdm import tqdm
except ImportError:
    tqdm = None


DEFAULT_BASE_URL = "https://nomad-lab.eu/prod/v1/api/v1"
DEFAULT_PAGE_SIZE = 100
DEFAULT_OUT_DIR = "output"
DEFAULT_PREFIX = "psc_encapsulation_stability"


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("nomad_exporter")


def post_json_request(url: str, json_body: Dict[str, Any], timeout: int = 120) -> Dict[str, Any]:
    """
    Sends a POST request with a JSON payload using requests (if available) or urllib.request.
    """
    if requests is not None:
        resp = requests.post(url, json=json_body, timeout=timeout)
        resp.raise_for_status()
        return resp.json()
    elif urllib is not None:
        data_bytes = json.dumps(json_body).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data_bytes,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "NOMAD-PSC-Exporter/1.0",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as response:
            res_text = response.read().decode("utf-8")
            return json.loads(res_text)
    else:
        raise RuntimeError("Neither 'requests' nor 'urllib.request' is available.")


def is_populated(val: Any) -> bool:
    """
    Recursively check whether a NOMAD quantity or subsection contains data.
    Returns False for None, empty strings, empty collections, or dicts with only unpopulated values.
    """
    if val is None:
        return False
    if isinstance(val, bool):
        return val
    if isinstance(val, (int, float)):
        return True
    if isinstance(val, str):
        return val.strip() != ""
    if isinstance(val, (list, tuple, set)):
        return any(is_populated(item) for item in val)
    if isinstance(val, dict):
        # Ignore nomad internal metadata keys starting with 'm_' or '_'
        valid_items = [v for k, v in val.items() if not str(k).startswith(("m_", "_"))]
        return any(is_populated(v) for v in valid_items)
    return True


def check_entry_matches(entry: Dict[str, Any]) -> Tuple[bool, bool, bool]:
    """
    Evaluates whether an entry has populated encapsulation and stability data.
    Returns (matches_both, has_encapsulation, has_stability).
    """
    archive = entry.get("archive", {})
    data = archive.get("data", {})
    if not isinstance(data, dict):
        return False, False, False

    # Check Encapsulation
    encapsulation_data = data.get("encapsulation")
    has_encapsulation = is_populated(encapsulation_data)

    # Check Stability
    stability_keys = [
        "stability",
        "operational_stability",
        "shelf_life_stability",
        "environmental_stability",
        "stabilised",
    ]
    has_stability = any(is_populated(data.get(key)) for key in stability_keys)

    matches_both = has_encapsulation and has_stability
    return matches_both, has_encapsulation, has_stability


def fetch_nomad_archive_entries(
    base_url: str = DEFAULT_BASE_URL,
    page_size: int = DEFAULT_PAGE_SIZE,
    max_pages: Optional[int] = None,
    start_page_after: Optional[str] = None,
    timeout: int = 120,
    retry_count: int = 3,
    checkpoint_callback = None,
) -> Iterator[Dict[str, Any]]:
    """
    Iterates through entries in NOMAD using pagination.page_after_value.
    Supports starting from a saved page_after cursor for seamless resuming.
    """
    url = f"{base_url.rstrip('/')}/entries/archive/query"
    page_after = start_page_after
    page_num = 0

    queries_to_try = [
        {"results.eln.sections": "PerovskiteSolarCell"},
        {"entry_type": "PerovskiteSolarCell"},
        {},  # Fallback to scanning public entries with selective required fields
    ]

    selected_query = None
    
    for q_candidate in queries_to_try:
        body = {
            "owner": "public",
            "query": q_candidate,
            "pagination": {"page_size": 1, "order_by": "entry_id", "order": "asc"},
            "required": {"include": ["entry_id"]},
        }
        try:
            res = post_json_request(url, body, timeout=30)
            total = res.get("pagination", {}).get("total", 0)
            if total > 0:
                selected_query = q_candidate
                logger.info(f"Targeting NOMAD query '{q_candidate}' (found ~{total} entries)")
                break
        except Exception as e:
            logger.debug(f"Candidate query check failed for {q_candidate}: {e}")

    if selected_query is None:
        selected_query = {}
        logger.info("Using standard public entry query with archive field selectivity.")

    if start_page_after:
        logger.info(f"Resuming query starting after cursor: '{start_page_after}'")

    while True:
        if max_pages is not None and page_num >= max_pages:
            logger.info(f"Reached user-specified maximum pages limit ({max_pages}).")
            break

        body = {
            "owner": "public",
            "query": selected_query,
            "pagination": {
                "page_size": page_size,
                "order_by": "entry_id",
                "order": "asc",
            },
            "required": {
                "include": [
                    "entry_id",
                    "upload_id",
                    "entry_name",
                    "entry_type",
                    "results.eln.sections",
                    "data.encapsulation",
                    "data.stability",
                    "data.operational_stability",
                    "data.shelf_life_stability",
                    "data.environmental_stability",
                    "data.cell",
                    "data.perovskite",
                    "data.module",
                ]
            },
        }

        if page_after:
            body["pagination"]["page_after_value"] = page_after

        # HTTP Request with retry loop and NOMAD rate-limiting compliance (1 req / 5s)
        response_data = None
        for attempt in range(retry_count):
            try:
                response_data = post_json_request(url, body, timeout=timeout)
                break
            except Exception as err:
                err_str = str(err)
                if "429" in err_str or "Too Many Requests" in err_str or "rate-limited" in err_str:
                    backoff = 6 * (attempt + 1)
                    logger.warning(f"NOMAD API rate limit encountered on page {page_num + 1}. Retrying in {backoff}s...")
                    time.sleep(backoff)
                else:
                    logger.warning(
                        f"API request error on page {page_num + 1} (attempt {attempt + 1}/{retry_count}): {err}"
                    )
                    if attempt == retry_count - 1:
                        logger.error("Max retries exceeded. Stopping archive retrieval.")
                        return
                    time.sleep(3 * (attempt + 1))

        if not response_data:
            break

        entries = response_data.get("data", [])
        if not entries:
            logger.info("No more entries returned by NOMAD API.")
            break

        for entry in entries:
            yield entry

        page_num += 1
        pagination = response_data.get("pagination", {})
        page_after = pagination.get("next_page_after_value")

        if checkpoint_callback:
            checkpoint_callback(page_after, page_num)

        if not page_after:
            break

        # Respect NOMAD endpoint rate-limit rule (new connection allowed every 5 seconds)
        time.sleep(5.1)


def flatten_dict(
    d: Dict[str, Any], parent_key: str = "", sep: str = "."
) -> Dict[str, Any]:
    """
    Flattens a deeply nested dictionary into a single-level key-value dictionary.
    Formats lists as comma-separated or JSON strings for CSV/Excel output.
    """
    items: List[Tuple[str, Any]] = []
    for k, v in d.items():
        if str(k).startswith(("m_", "_")):
            continue
        new_key = f"{parent_key}{sep}{k}" if parent_key else str(k)
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        elif isinstance(v, (list, tuple)):
            if len(v) == 0:
                items.append((new_key, ""))
            elif all(isinstance(x, (str, int, float, bool)) for x in v):
                items.append((new_key, ", ".join(str(x) for x in v)))
            else:
                items.append((new_key, json.dumps(v, ensure_ascii=False)))
        else:
            items.append((new_key, v))
    return dict(items)


def create_summary_record(entry: Dict[str, Any]) -> Dict[str, Any]:
    """
    Converts a NOMAD entry into a flat dictionary suitable for tabular export.
    """
    archive = entry.get("archive", {})
    data = archive.get("data", {}) if isinstance(archive.get("data"), dict) else {}

    record = {
        "entry_id": entry.get("entry_id", ""),
        "upload_id": entry.get("upload_id", ""),
        "entry_name": entry.get("entry_name", ""),
        "entry_type": entry.get("entry_type", ""),
        "nomad_url": f"https://nomad-lab.eu/prod/v1/gui/entry/id/{entry.get('upload_id')}/{entry.get('entry_id')}"
        if entry.get("upload_id") and entry.get("entry_id")
        else "",
    }

    # Flatten encapsulation
    encap_data = data.get("encapsulation", {})
    if isinstance(encap_data, dict):
        flat_encap = flatten_dict(encap_data, parent_key="encapsulation")
        record.update(flat_encap)
    elif is_populated(encap_data):
        record["encapsulation"] = str(encap_data)

    # Flatten stability subsections
    stability_keys = [
        "stability",
        "operational_stability",
        "shelf_life_stability",
        "environmental_stability",
        "stabilised",
    ]
    for skey in stability_keys:
        stab_val = data.get(skey)
        if isinstance(stab_val, dict):
            flat_stab = flatten_dict(stab_val, parent_key=skey)
            record.update(flat_stab)
        elif is_populated(stab_val):
            record[skey] = str(stab_val)

    # Cell and Perovskite metadata if present
    for mkey in ["cell", "perovskite"]:
        mval = data.get(mkey)
        if isinstance(mval, dict):
            flat_m = flatten_dict(mval, parent_key=mkey)
            record.update(flat_m)

    return record


def export_dataset(
    matching_entries: List[Dict[str, Any]],
    out_dir: Union[str, Path],
    prefix: str,
    export_format: str,
) -> List[Path]:
    """
    Exports matching entry dataset into requested formats (json, csv, excel, or all).
    """
    out_path = Path(out_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    created_files: List[Path] = []

    formats_to_export = (
        ["json", "csv", "excel"] if export_format.lower() == "all" else [export_format.lower()]
    )

    # Export JSON
    if "json" in formats_to_export:
        json_file = out_path / f"{prefix}.json"
        with open(json_file, "w", encoding="utf-8") as f:
            json.dump(matching_entries, f, indent=2, ensure_ascii=False)
        logger.info(f"Saved JSON export: {json_file} ({len(matching_entries)} entries)")
        created_files.append(json_file)

    # Flatten records for Tabular exports (CSV & Excel)
    if any(fmt in formats_to_export for fmt in ["csv", "excel"]):
        records = [create_summary_record(e) for e in matching_entries]
        
        if "csv" in formats_to_export:
            csv_file = out_path / f"{prefix}.csv"
            if pd is not None:
                df = pd.DataFrame(records)
                df.to_csv(csv_file, index=False, encoding="utf-8")
                logger.info(f"Saved CSV export via pandas: {csv_file} ({df.shape[0]} rows, {df.shape[1]} columns)")
            else:
                # Built-in csv fallback
                fieldnames = []
                for r in records:
                    for k in r.keys():
                        if k not in fieldnames:
                            fieldnames.append(k)
                with open(csv_file, "w", newline="", encoding="utf-8") as f:
                    writer = csv.DictWriter(f, fieldnames=fieldnames)
                    writer.writeheader()
                    writer.writerows(records)
                logger.info(f"Saved CSV export via built-in csv module: {csv_file} ({len(records)} rows, {len(fieldnames)} columns)")
            created_files.append(csv_file)

        if "excel" in formats_to_export or "xlsx" in formats_to_export:
            xlsx_file = out_path / f"{prefix}.xlsx"
            if pd is None:
                logger.warning("Pandas is not installed; skipping Excel export. Install pandas and openpyxl for Excel output.")
            else:
                df = pd.DataFrame(records)
                try:
                    with pd.ExcelWriter(xlsx_file, engine="openpyxl") as writer:
                        df.to_excel(writer, sheet_name="PSC_Data", index=False)
                        worksheet = writer.sheets["PSC_Data"]
                        for col in worksheet.columns:
                            max_len = max(len(str(cell.value or "")) for cell in col)
                            col_letter = col[0].column_letter
                            worksheet.column_dimensions[col_letter].width = min(max_len + 3, 50)
                    logger.info(f"Saved Excel export: {xlsx_file} ({df.shape[0]} rows, {df.shape[1]} columns)")
                    created_files.append(xlsx_file)
                except Exception as e:
                    logger.error(f"Failed to write Excel file: {e}")

    return created_files



def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download & Filter PerovskiteSolarCell entries from NOMAD API."
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help=f"NOMAD API Base URL (default: {DEFAULT_BASE_URL})",
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=DEFAULT_PAGE_SIZE,
        help=f"API Page Size (default: {DEFAULT_PAGE_SIZE})",
    )
    parser.add_argument(
        "--max-entries",
        type=int,
        default=None,
        help="Maximum matching entries to collect (default: collect all)",
    )
    parser.add_argument(
        "--max-pages",
        type=int,
        default=None,
        help="Maximum API pages to scan (default: scan all pages)",
    )
    parser.add_argument(
        "--out-dir",
        default=DEFAULT_OUT_DIR,
        help=f"Output directory (default: {DEFAULT_OUT_DIR})",
    )
    parser.add_argument(
        "--output-prefix",
        default=DEFAULT_PREFIX,
        help=f"Filename prefix for exports (default: {DEFAULT_PREFIX})",
    )
    parser.add_argument(
        "--format",
        choices=["json", "csv", "excel", "all"],
        default="all",
        help="Export format (default: all)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=120,
        help="HTTP request timeout in seconds (default: 120)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose debug logging",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    logger.info("Starting NOMAD Perovskite Solar Cell Exporter")
    logger.info(f"Target NOMAD Base URL: {args.base_url}")
    logger.info("Filter Criteria: populated 'encapsulation' AND populated 'stability'")

    out_path = Path(args.out_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    checkpoint_file = out_path / "checkpoint.json"

    start_cursor = None
    scanned_count = 0
    matched_entries = []

    # Check for existing checkpoint to resume
    if checkpoint_file.exists() and not getattr(args, "reset", False):
        try:
            with open(checkpoint_file, "r", encoding="utf-8") as f:
                chk = json.load(f)
                start_cursor = chk.get("page_after")
                scanned_count = chk.get("scanned_count", 0)
                logger.info(f"Checkpoint found! Resuming from cursor '{start_cursor}' (previously scanned: {scanned_count})")
            
            # Load previously saved matching entries
            json_export = out_path / f"{args.output_prefix}.json"
            if json_export.exists():
                with open(json_export, "r", encoding="utf-8") as f:
                    matched_entries = json.load(f)
                logger.info(f"Loaded {len(matched_entries)} previously matched entries from disk.")
        except Exception as e:
            logger.warning(f"Could not load checkpoint ({e}). Starting fresh scan.")
            start_cursor = None
            scanned_count = 0
            matched_entries = []

    def update_checkpoint(cursor_val, current_page):
        chk_data = {
            "page_after": cursor_val,
            "scanned_count": scanned_count,
            "matched_count": len(matched_entries),
            "last_updated": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        with open(checkpoint_file, "w", encoding="utf-8") as f:
            json.dump(chk_data, f, indent=2)

    iterator = fetch_nomad_archive_entries(
        base_url=args.base_url,
        page_size=args.page_size,
        max_pages=args.max_pages,
        start_page_after=start_cursor,
        timeout=args.timeout,
        checkpoint_callback=update_checkpoint,
    )

    if tqdm:
        pbar = tqdm(desc="Scanning NOMAD Entries", unit=" entry")
    else:
        pbar = None

    for entry in iterator:
        scanned_count += 1
        if pbar:
            pbar.update(1)
        elif scanned_count % 100 == 0:
            logger.info(f"Scanned {scanned_count} entries...")

        matches_both, has_encap, has_stab = check_entry_matches(entry)

        if matches_both:
            matched_entries.append(entry)
            logger.info(
                f"Match found! entry_id: {entry.get('entry_id')} (Total matched: {len(matched_entries)})"
            )
            export_dataset(
                matching_entries=matched_entries,
                out_dir=args.out_dir,
                prefix=args.output_prefix,
                export_format=args.format,
            )
            if args.max_entries and len(matched_entries) >= args.max_entries:
                logger.info(f"Reached requested max-entries limit ({args.max_entries}). Stopping scan.")
                break

    if pbar:
        pbar.close()

    logger.info(
        f"Scan complete. Total scanned: {scanned_count} entries. Total matched: {len(matched_entries)} entries."
    )

    if not matched_entries:
        logger.warning("No entries matched both encapsulation and stability filter criteria.")

    created_files = export_dataset(
        matching_entries=matched_entries,
        out_dir=args.out_dir,
        prefix=args.output_prefix,
        export_format=args.format,
    )

    logger.info("Export summary:")
    for fpath in created_files:
        logger.info(f"  - {fpath.resolve()}")


if __name__ == "__main__":
    main()
