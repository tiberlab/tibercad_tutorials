#!/bin/bash
# --- PARAMETRI GEOMETRICI E LUCE (Dal file .geo) ---
W_CM=4.0             # Larghezza cella: 40 mm = 4 cm
L_CM=0.5             # Lunghezza cella: 5 mm = 0.5 cm
N_CELLS=5            # Numero di sottocelle
# Calcolo Area Attiva Totale in cm^2 (4 * 0.5 * 5 = 10.0 cm^2)
AREA_ATTIVA=$(echo "$W_CM $L_CM $N_CELLS" | awk '{print $1 * $2 * $3}')

PIN_MW_CM2=100.0     # Potenza incidente standard AM1.5G (100 mW/cm^2)
# Potenza luminosa totale incidente sull'area attiva (in Watt): (100 * 0.001) * 10.0 = 1.0 W
P_IN_TOTAL=$(echo "$PIN_MW_CM2 $AREA_ATTIVA" | awk '{print ($1 * 0.001) * $2}')
# Intestazione del file di output CSV
OUTPUT_FILE="riepilogo_moduli_perovskite.csv"
echo "Cartella,Materiale,Temperatura,Tempo,Umidita,Isc_A,Voc_V,Pmax_W,FF_perc,Eff_Attiva_perc" > "$OUTPUT_FILE"

echo "=== INIZIO ANALISI APERTA: AREA ATTIVA = ${AREA_ATTIVA} cm² ==="
# Ciclo su tutte le cartelle conformi al pattern
for dir in */ ; do
    dir_name="${dir%/}"
    FILE_DAT="${dir_name}/equiv_circ_pv.dat"

    # Verifica presenza del file di simulazione
    if [ ! -f "$FILE_DAT" ]; then
        continue
    fi

    echo "Elaborazione: $dir_name ..."

    # --- 1. PARSING METADATI CARTELLA ---
    # Esempio: EVA_T_300_t_1_RH50
    MATERIALE=$(echo "$dir_name" | cut -d'_' -f1)
    TEMPERATURA=$(echo "$dir_name" | cut -d'_' -f3)
    TEMPO=$(echo "$dir_name" | cut -d'_' -f5)
    UMIDITA=$(echo "$dir_name" | cut -d'_' -f6)
    UMIDITA="${UMIDITA#RH}" # Rimuove la sigla RH lasciando solo il numero

    # --- 2. ELABORAZIONE NUMERICA CON AWK (Salto 11 righe di commento) ---
    RISULTATI=$(awk -v p_in="$P_IN_TOTAL" '
    BEGIN {
        min_v_diff = 999999;
        isc_raw = 0;
        p_max = -999999;
        count = 0;
    }
    
    # Salta le 11 righe di intestazione con # e le righe vuote
    $1 ~ /^#/ || NF < 2 { next }

    {
        count++;
        v[count] = $1;
        # Nota: usiamo direttamente la corrente passata ($2). 
        # Se i grafici di potenza dovessero uscire invertiti, ripristina il segno meno (-$2).
        i[count] = -$2; 
        
        # Potenza generata P = V * I (in Watt)
        p[count] = v[count] * i[count];

        # Trova Isc (corrente a V più vicina a 0V)
        v_abs = (v[count] < 0) ? -v[count] : v[count];
        if (v_abs < min_v_diff) {
            min_v_diff = v_abs;
            isc_raw = i[count];
        }

        # Traccia il Punto di Massima Potenza (Pmax)
        if (p[count] > p_max) {
            p_max = p[count];
        }
    }

    END {
        if (count < 2) {
            print "0 0 0 0 0";
            exit;
        }

        # Calcolo Voc cercando un attraversamento dello zero di corrente
        voc = 0;
        for (j = 1; j < count; j++) {
            if ((i[j] >= 0 && i[j+1] <= 0) || (i[j] <= 0 && i[j+1] >= 0)) {
                if (i[j+1] != i[j]) {
                    voc = v[j] - i[j] * (v[j+1] - v[j]) / (i[j+1] - i[j]);
                } else {
                    voc = v[j];
                }
                break;
            }
        }
        if (voc == 0) voc = v[count];

        # Calcolo Fill Factor ed Efficienza Percentuale
        if (isc_raw <= 0 || voc <= 0 || p_max <= 0) {
            ff = 0;
            eff = 0;
        } else {
            ff = (p_max / (isc_raw * voc)) * 100;
            eff = (p_max / p_in) * 100;
        }

        printf "%.6e %.4f %.6e %.2f %.2f", isc_raw, voc, p_max, ff, eff;
    }' "$FILE_DAT")

    # Parsing delle variabili calcolate da awk
    read -r ISC VOC PMAX FF EFF <<< "$RISULTATI"

    # --- 3. SCRITTURA FILE CSV REGISTRATO ---
    echo "$dir_name,$MATERIALE,${TEMPERATURA}K,${TEMPO},${UMIDITA}%,$ISC,$VOC,$PMAX,$FF,$EFF" >> "$OUTPUT_FILE"
done

echo "=== ANALISI COMPLETATA ==="
echo "I dati comprensivi di efficienza attiva sono pronti in: $OUTPUT_FILE"



