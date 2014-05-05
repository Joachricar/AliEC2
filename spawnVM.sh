#!/bin/bash

if [ $# = 0 ]; then
	exit;
fi

wget http://localhost:3000/spawn/$1/$1/$1 | cat
