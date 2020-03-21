#!/bin/sh
SHA=`git rev-parse --short HEAD`
HUGO_IDENTITY="~/.ssh/hugo"

cd nornir-automation.github.io

if [ -f $HUGO_IDENTITY ]; then
	IDENTITY=-i HUGO_IDENTITY
fi

git add .
git commit -m "published from nornir.tech.src $SHA"
git push origin HEAD:master
