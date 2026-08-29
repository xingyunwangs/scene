SHELL := /bin/bash

.DEFAULT_GOAL := app

.PHONY: test app install shot verify interaction-test clean

test:
	swift test --disable-sandbox

app:
	bash Scripts/make-app.sh

install: app
	bash Scripts/install-app.sh

shot:
	swift build --disable-sandbox
	.build/debug/Scene shot dist/scene.png

verify:
	bash Scripts/verify.sh

interaction-test:
	bash Scripts/interaction-smoke.sh

clean:
	rm -rf .build dist
