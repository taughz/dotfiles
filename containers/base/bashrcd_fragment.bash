
########## BASHRC.D BEGIN ##########
declare -a brc_files
bashrc_d="$HOME/.bashrc.d"
if [[ -d $bashrc_d ]]; then
    readarray -t -d '' brc_files < \
        <(find $bashrc_d -type f -regex '.*\.\(ba\)?sh$' -print0 | LC_ALL=C sort -z)
fi
declare -A brc_elapsed
for brc_file in "${brc_files[@]}"; do
    start_time=$EPOCHREALTIME
    source "$brc_file"
    end_time=$EPOCHREALTIME
    brc_elapsed["$brc_file"]=$(awk 'BEGIN {printf "%.2f", '"($end_time - $start_time)}")
done
: "${BASHRC_D_PROFILE:=0}"
if [[ $BASHRC_D_PROFILE -ne 0 ]] && [[ ${#brc_elapsed[@]} -gt 0 ]]; then
    echo "Elapsed time to source '.bashrc.d':"
    for brc_file in "${!brc_elapsed[@]}"; do
        printf "%s %s\n" "${brc_elapsed[$brc_file]}" "$(basename "$brc_file")"
    done | sort -rn | while read -r time name; do
        printf "  - %-20s %10s seconds\n" "$name" "$time"
    done
fi
########### BASHRC.D END ###########
