
########## BASHRC.D BEGIN ##########
declare -a _brc_files=()
for _brc_dir in "$HOME/.bashrc.d" "${HOST_BASHRC_DIR:-}"; do
    [[ -d $_brc_dir ]] || continue
    readarray -t -d '' -O ${#_brc_files[@]} _brc_files < \
        <(find $_brc_dir -type f -regex '.*\.\(ba\)?sh$' -print0 | LC_ALL=C sort -z)
done
declare -A _brc_elapsed=()
for _brc_file in "${_brc_files[@]}"; do
    _brc_start_time=$EPOCHREALTIME
    source "$_brc_file"
    _brc_end_time=$EPOCHREALTIME
    _brc_elapsed["$_brc_file"]=$(awk 'BEGIN {printf "%.2f", '"($_brc_end_time - $_brc_start_time)}")
done
: "${BASHRC_D_PROFILE:=0}"
if [[ $BASHRC_D_PROFILE -ne 0 ]] && [[ ${#_brc_elapsed[@]} -gt 0 ]]; then
    echo "Elapsed time to source '.bashrc.d':"
    for _brc_file in "${!_brc_elapsed[@]}"; do
        printf "%s %s\n" "${_brc_elapsed[$_brc_file]}" "$(basename "$_brc_file")"
    done | sort -rn | while read -r time name; do
        printf "  - %-20s %10s seconds\n" "$name" "$time"
    done
fi
unset -v _brc_files _brc_dir _brc_elapsed _brc_file _brc_start_time _brc_end_time
########### BASHRC.D END ###########
