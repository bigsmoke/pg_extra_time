#!/bin/bash

SED_SCRIPT="/^create/{s/ or replace//;p}"

vimdiff \
    <(sed -n -E "$SED_SCRIPT" "$1" | sort) \
    <(sed -n -E "$SED_SCRIPT" "$2" | sort)
