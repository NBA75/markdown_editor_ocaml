# Raccourcis de développement.
# Astuce : exécutez « eval $(opam env) » une fois pour avoir dune dans le PATH.

OPAM ?= opam

.PHONY: help setup build test run clean

help: ## Affiche cette aide
	@echo "Cibles disponibles :"
	@echo "  make setup  - installe les dépendances OCaml du projet (opam)"
	@echo "  make build  - compile le projet (dune build)"
	@echo "  make test   - lance les tests (dune runtest)"
	@echo "  make run    - démarre le serveur (http://127.0.0.1:8080)"
	@echo "  make clean  - supprime les artefacts de compilation"

setup: ## Installe les dépendances (réseau requis ; voir aussi libev-dev)
	$(OPAM) install . --deps-only --with-test

build: ## Compile
	dune build

test: ## Tests
	dune runtest

run: ## Démarre le serveur web local
	dune exec bin/main.exe

clean: ## Nettoie _build/
	dune clean
