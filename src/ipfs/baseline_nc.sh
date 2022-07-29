#!/usr/bin/env bash
# Test file transfer wall time using netcat
# ./baseline_nc.sh <SSH_HOST> <NC_ADDRESS> <NC_PORT>
set -e
SSH_HOST="$1"
NC_ADDRESS="$2"
NC_PORT="$3"
CSV_FILE="baseline_netcat_duration_results.csv"

# Test configuration
FILES=('testfile_1_MiB.bin' 'testfile_10_MiB.bin' 'testfile_100_MiB.bin' 'testfile_500_MiB.bin' 'testfile_1_GiB.bin')
ROUNDS=20

echo 'Processing netcat baseline...'
# .csv header
DELIMITER=';'
echo "File${DELIMITER}SHA256${DELIMITER}Round${DELIMITER}Time_Total_Duration_Wall${DELIMITER}Match" > "$CSV_FILE"

# Run the test
for FILE in "${FILES[@]}"; do
  ROUND=0
  while [ $ROUND -lt $ROUNDS ]; do
    # Launch SSH tunnel to netcat server on remote host
    if [ $(ss -lt -H "( sport = :${NC_PORT} )" src "${NC_ADDRESS}" | wc -l) -ne 0 ]; then
      echo "Error: connection on ${NC_ADDRESS}:${NC_PORT} already exists!"
      exit 1      
    else
      ssh -f "$SSH_HOST" -L "${NC_ADDRESS}:${NC_PORT}:${NC_ADDRESS}:${NC_PORT}" "nc -d -N -l -s '$NC_ADDRESS' -p '$NC_PORT' > '$FILE'" >/dev/null 2>&1
    fi

    # Wait for connection
    sleep 3
    while [ $(ss -lt -H "( sport = :${NC_PORT} )" src "${NC_ADDRESS}" | wc -l) -ne 1 ]; do
      sleep 1
    done

    # Transfer file using netcat (TCP) and measure wall time
    TRANSFER_WALL_DURATION=$(2>&1 /usr/bin/time --format="\t%e" nc "$NC_ADDRESS" "$NC_PORT" < "$FILE" > /dev/null | cut -f2)

    # Verify checksum (has to match)
    SAME='no'
    HASH=$(<"${FILE}.sha256sum")
    HASH_REMOTE=$(ssh "$SSH_HOST" "sha256sum '$FILE' | cut -d' ' -f1" 2>/dev/null)
    if [ "$HASH_REMOTE" == "$HASH" ]; then
      SAME='yes'
    else
      echo "Warning: hash mismatch between original and transferred (file: $FILE)!"
    fi

    # Write results to .csv file and clean up test files / storage
    echo "${FILE}${DELIMITER}${HASH}${DELIMITER}$ROUND${DELIMITER}${TRANSFER_WALL_DURATION}${DELIMITER}${SAME}" >> "$CSV_FILE"
    ssh "$SSH_HOST" "rm '$FILE'" 2>/dev/null

    ROUND=$(($ROUND + 1))
  done
done
echo 'Done!'
