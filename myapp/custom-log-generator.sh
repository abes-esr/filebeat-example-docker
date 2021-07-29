#!/bin/bash

while true;
do
  sleep 2
  if [ $(shuf -i1-10 -n1) -gt 5 ]
  then
    echo "INFO - ca se passe bien"
  else
    echo "ERROR - ca se passe mal"
  fi
done
