#!/bin/bash

while true;
do
  sleep 2
  if [ $(shuf -i1-10 -n1) -gt 5 ]
  then
    # >&1 permet d'envoyer vers stdout
    echo "INFO - ca se passe bien" >&1
  else
    # >&1 permet d'envoyer vers stderr
    echo "ERROR - ca se passe mal" >&2
  fi
done
