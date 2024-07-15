#!/usr/bin/env bash

for theme in $(find ./mac_installers -type f -name '*.sh'); do
  sh "$theme"
done
