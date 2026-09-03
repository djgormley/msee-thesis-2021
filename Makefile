SHELL := /bin/sh
.DEFAULT_GOAL := verify

MATLAB ?= $(shell if command -v matlab >/dev/null 2>&1; then printf '%s' matlab; elif command -v matlab.exe >/dev/null 2>&1; then printf '%s' matlab.exe; else printf '%s' matlab; fi)
LATEXMK ?= latexmk

BUILD_DIR ?= build
THESIS_BUILD_DIR := $(BUILD_DIR)/thesis
ERRATA_BUILD_DIR := $(BUILD_DIR)/errata
RELEASE_DIR := output/pdf

LATEXMK_FLAGS := -pdf -interaction=nonstopmode -halt-on-error -file-line-error

.PHONY: figures matlab-test thesis errata verify release clean check-manifests

figures:
	"$(MATLAB)" -batch "addpath('matlab'); generate_all_plots;"

matlab-test:
	"$(MATLAB)" -batch "addpath('matlab'); results = runtests('matlab/tests', 'IncludeSubfolders', true); assertSuccess(results);"

thesis:
	mkdir -p "$(THESIS_BUILD_DIR)"
	$(LATEXMK) $(LATEXMK_FLAGS) -outdir="$(abspath $(THESIS_BUILD_DIR))" main.tex

errata:
	mkdir -p "$(ERRATA_BUILD_DIR)"
	cd errata && $(LATEXMK) $(LATEXMK_FLAGS) -outdir="$(abspath $(ERRATA_BUILD_DIR))" errata.tex

check-manifests:
	cd supporting-materials/characterization && sha256sum --check MANIFEST.sha256
	cd supporting-materials/spectrum-sensor && sha256sum --check MANIFEST.sha256

verify: matlab-test check-manifests thesis errata

release: figures
	$(MAKE) verify
	mkdir -p "$(RELEASE_DIR)"
	cp "$(THESIS_BUILD_DIR)/main.pdf" "$(RELEASE_DIR)/msee-thesis-2021.pdf"
	cp "$(ERRATA_BUILD_DIR)/errata.pdf" "$(RELEASE_DIR)/msee-thesis-2021-errata.pdf"

clean:
	rm -rf -- "$(BUILD_DIR)"
