#!/bin/bash

# Get the current month and year
current_month=$(date +'%m')
current_year=$(date +'%Y')

# Define an array to store the number of days in each month
days_in_month=(31 28 31 30 31 30 31 31 30 31 30 31)

# Check if the current year is a leap year
is_leap_year=false
if ((current_year % 4 == 0 && (current_year % 100 != 0 || current_year % 400 == 0)); then
  is_leap_year=true
fi

# Determine the number of days in the current month
num_days=0

if [ $current_month -eq 2 ]; then
  # February
  if [ "$is_leap_year" = true ]; then
    num_days=29
  else
    num_days=28
  fi
else
  num_days=${days_in_month[$current_month - 1]}
fi

# Print the information
echo "Current month: $current_month"
echo "Number of days in the current month: $num_days"

if [ $current_month -eq 2 ]; then
  if [ "$is_leap_year" = true ]; then
    echo "This is a leap year."
  else
    echo "This is not a leap year."
  fi
fi
