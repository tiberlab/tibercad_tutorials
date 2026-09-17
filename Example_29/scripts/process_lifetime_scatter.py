import json
import csv
import math
import os

def classify_entry(sealant_str, atmosphere_str, stack_str):
    atm = str(atmosphere_str or "").strip().lower()
    sealant = str(sealant_str or "").strip().lower()
    stack = str(stack_str or "").strip().lower()

    # Rule 1: Exclude dark or inert atmosphere tests without oxygen
    is_oxygen_light = any(k in atm for k in ['air', 'ambient']) and not any(k in atm for k in ['n2', 'argon', 'vacuum'])
    if not is_oxygen_light:
        return "Other"

    # Rule 2: Check for High-Tech Next-Gen Strategic Encapsulants & Multilayer Barriers (Blue)
    is_hitech_strategic = any(k in stack for k in ['kapton', 'cover glass-qds', 'barrier foil', 'surlyn', 'pvb']) or \
                         any(k in sealant for k in ['pvb', 'polyvinyl butyral', 'surlyn', 'acrylic', 'pmma'])

    if is_hitech_strategic:
        return "PVB_NextGen" # Blue Series

    # Rule 3: Simple POE / PIB (Green)
    if any(k in sealant for k in ['poe', 'polyolefin', 'pib', 'polyisobutylene', 'polyisobutene']):
        return "POE" # Green Series

    # Rule 4: Simple EVA / Epoxy (Red)
    if any(k in sealant for k in ['eva', 'epoxy', 'glue', 'threebond', 'noa', 'adhesive']):
        return "EVA" # Red Series

    return "Other"

def process_lifetime_data(json_path, csv_out_path):
    with open(json_path, 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    scatter_points = []
    
    for idx, entry in enumerate(data):
        entry_id = entry.get("entry_id", f"entry_{idx}")
        archive = entry.get("archive", {}).get("data", {})
        
        stability = archive.get("stability", {})
        stabilised = archive.get("stabilised", {})
        jv = archive.get("jv", {})
        encap = archive.get("encapsulation", {})
        
        atmosphere = stability.get("atmosphere", "Unknown")
        stack_seq  = encap.get("stack_sequence", "Unknown")
        sealant    = encap.get("edge_sealing_materials", "Unknown")
        
        if atmosphere in (None, "", "nan"): atmosphere = "Unknown"
        if sealant in (None, "", "nan"): sealant = "Unknown"
        
        category = classify_entry(sealant, atmosphere, stack_seq)

        # Determine Initial PCE
        pce_init = None
        pce_init_val = stability.get("PCE_initial_value")
        if pce_init_val not in (None, "Unknown", "nan", ""):
            try:
                val = float(pce_init_val)
                if val > 0: pce_init = val
            except ValueError: pass
            
        if pce_init is None:
            pce_jv = jv.get("default_PCE")
            if pce_jv not in (None, "Unknown", "nan", ""):
                try:
                    val = float(pce_jv)
                    if val > 0: pce_init = val
                except ValueError: pass

        if pce_init is None:
            pce_stab = stabilised.get("performance_PCE")
            if pce_stab not in (None, "Unknown", "nan", ""):
                try:
                    val = float(pce_stab)
                    if val > 0: pce_init = val
                except ValueError: pass

        entry_points_count = 0

        # Point A: T80 -> (T80_hours, 0.8)
        t80_val = stability.get("PCE_T80")
        if t80_val not in (None, "Unknown", "nan", ""):
            try:
                t80 = float(t80_val)
                if t80 > 0:
                    scatter_points.append({
                        "entry_id": entry_id,
                        "sealant": sealant,
                        "atmosphere": atmosphere,
                        "category": category,
                        "time_hours": t80,
                        "pce_normalized": 0.80,
                        "metric_type": "T80"
                    })
                    entry_points_count += 1
            except ValueError: pass

        # Point B: T95 -> (T95_hours, 0.95)
        t95_val = stability.get("PCE_T95")
        if t95_val not in (None, "Unknown", "nan", ""):
            try:
                t95 = float(t95_val)
                if t95 > 0:
                    scatter_points.append({
                        "entry_id": entry_id,
                        "sealant": sealant,
                        "atmosphere": atmosphere,
                        "category": category,
                        "time_hours": t95,
                        "pce_normalized": 0.95,
                        "metric_type": "T95"
                    })
                    entry_points_count += 1
            except ValueError: pass

        # Point C: PCE after 1000h
        p1000_val = stability.get("PCE_after_1000_h")
        if p1000_val not in (None, "Unknown", "nan", ""):
            try:
                p1000 = float(p1000_val)
                if pce_init and pce_init > 0:
                    norm_pce = p1000 / pce_init
                    if norm_pce > 1.5: norm_pce /= 100.0
                    if 0.0 <= norm_pce <= 1.2:
                        scatter_points.append({
                            "entry_id": entry_id,
                            "sealant": sealant,
                            "atmosphere": atmosphere,
                            "category": category,
                            "time_hours": 1000.0,
                            "pce_normalized": round(norm_pce, 4),
                            "metric_type": "PCE_1000h"
                        })
                        entry_points_count += 1
            except ValueError: pass

        # Point D: PCE end of experiment + total exposure time
        texp_val = stability.get("time_total_exposure")
        pend_val = stability.get("PCE_end_of_experiment")
        if texp_val not in (None, "Unknown", "nan", "") and pend_val not in (None, "Unknown", "nan", ""):
            try:
                texp = float(texp_val)
                pend = float(pend_val)
                if texp > 0 and pce_init and pce_init > 0:
                    norm_pce = pend / pce_init
                    if norm_pce > 1.5: norm_pce /= 100.0
                    if 0.0 <= norm_pce <= 1.2:
                        scatter_points.append({
                            "entry_id": entry_id,
                            "sealant": sealant,
                            "atmosphere": atmosphere,
                            "category": category,
                            "time_hours": texp,
                            "pce_normalized": round(norm_pce, 4),
                            "metric_type": "PCE_end"
                        })
                        entry_points_count += 1
            except ValueError: pass

        # Baseline point (t=0, PCE_norm=1.0)
        if entry_points_count > 0 or pce_init is not None:
            scatter_points.append({
                "entry_id": entry_id,
                "sealant": sealant,
                "atmosphere": atmosphere,
                "category": category,
                "time_hours": 0.0,
                "pce_normalized": 1.00,
                "metric_type": "Initial"
            })

    os.makedirs(os.path.dirname(csv_out_path), exist_ok=True)
    fieldnames = ["entry_id", "sealant", "atmosphere", "category", "time_hours", "pce_normalized", "metric_type"]
    with open(csv_out_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(scatter_points)

    print(f"Generated {len(scatter_points)} scatter points across {len(data)} entries!")
    return scatter_points

if __name__ == "__main__":
    json_in = "output/psc_encapsulation_stability.json"
    csv_out = "output/lifetime_scatter_points.csv"
    pts = process_lifetime_data(json_in, csv_out)
