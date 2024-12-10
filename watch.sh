#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

while true
do
    # Get the current time
    TIME=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Execute shiroa build
    if shiroa build >/dev/null 2>&1; then
        echo "[shiroa watch @ ($TIME)] - Build Successful"
    else
        echo -e "${RED}[shiroa watch @ ($TIME)] - Build Failed${NC}"
    fi

    # Wait 1 seconds before the next iteration
    sleep 1
done