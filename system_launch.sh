#!/bin/bash

# Список скриптов для запуска
scripts=(
    "./GenTargets.sh"
    "./kp_vko.sh"
    "./Rls1.sh"
    "./Rls2.sh"
    "./Rls3.sh"
    "./Spro.sh"
    "./Zrdn1.sh"
    "./Zrdn2.sh"
    "./Zrdn3.sh"
)

for script in "${scripts[@]}"; do
    "$script" &   
    sleep 1      
done
