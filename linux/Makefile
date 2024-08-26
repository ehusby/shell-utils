.DEFAULT_GOAL := help

.PHONY: help
help:  # This help
	@for makefile in $(MAKEFILE_LIST); do \
    	echo "[$${makefile}]"; \
		grep -hE '^[a-zA-Z-][a-zA-Z0-9_\.-]+:' "$$makefile" | sed -r -e 's/(^[^#]+)#+[[:space:]]*(.+$$)/\1AWK_TARGET_DESC_DELIM\2/' -e 's/:*[[:space:]]*AWK_TARGET_DESC_DELIM/AWK_TARGET_DESC_DELIM/' -e 's/:+$$//' | sort | awk 'BEGIN {FS="AWK_TARGET_DESC_DELIM"}; {target=$$1; desc=$$2; gsub(/:$$/,"",target); if (length(target)>30 && NF>1 && length(desc)>0) {printf "\033[36m%s\n", target; printf "%-30s", "";} else {printf "\033[36m%-30s", target;}; printf "\033[0m %s\n", desc;}' | sed -e "s/TESTS_DIR/${TESTS_DIR}/g" -e "s/PROJECT_DIR/${PROJECT_DIR}/g"; \
		echo; \
	done

# poetry venv

.PHONY: install-venv
install-venv:  # Install/update python poetry environment defined in 'pyproject.toml' file
	poetry install --sync

# linting, formatting and type checking

.PHONY: ruff-lint-check
ruff-lint-check:  # Run python ruff linter checks
	ruff check .

.PHONY: ruff-lint-fix
ruff-lint-fix:  # Run python ruff linter and apply automatic 'safe' fixes
	ruff check . --fix

.PHONY: ruff-format-check
ruff-format-check:  # Run python ruff formatter checks
	ruff format . --check

.PHONY: ruff-format-fix
ruff-format-fix:  # Run python ruff formatter fixes
	ruff format .

.PHONY: ruff-checks
ruff-checks: ruff-lint-check ruff-format-check  # Run python ruff linter and formatter checks

.PHONY: ruff-fixes
ruff-fixes: ruff-lint-fix ruff-format-fix  # Run python ruff linter and formatter fixes

.PHONY: mypy
mypy:  # Run python mypy type checks
	mypy .

.PHONY: pre-commits
pre-commits:  # Run pre-commit hooks defined in top-level 'pre-commit-config.yaml' file
	-pre-commit run --all-files

.PHONY: check
check: ruff-lint-check ruff-format-check mypy  # Run ruff linter and formatter checks, mypy type checks

.PHONY: format
format: pre-commits ruff-lint-fix ruff-format-fix mypy  # Run pre-commit hooks, ruff linter and formatter fixes, mypy type checks

# tests

.PHONY: run-unit-tests
run-unit-tests:  # Run pytest tests defined in 'TESTS_DIR/'
	pytest ${TESTS_DIR}/

.PHONY: run-unit-tests-with-cov-file
run-unit-tests-with-cov-file:  # Run pytest tests defined in 'TESTS_DIR/', generate code coverage map for 'PROJECT_DIR/'
	pytest ${TESTS_DIR}/ --cov-report xml:cov.xml --cov ${PROJECT_DIR}/

# docker compose commands

.PHONY: up
up:  # Run 'docker compose up --detach --renew-anon-volumes'
	docker compose up --detach --renew-anon-volumes

.PHONY: up-build
up-build:  # Run 'docker compose up --detach --build --renew-anon-volumes'
	docker compose up --detach --build --renew-anon-volumes

.PHONY: down
down:  # Run 'docker compose down'
	docker compose down

.PHONY: down-prune
down-prune:  # Run 'docker compose down --volumes'
	docker compose down --volumes

.PHONY: stop
stop:  # Run 'docker compose stop'
	docker compose stop

.PHONY: logs
logs:  # Run 'docker compose logs --follow --timestamps'
	docker compose logs --follow --timestamps

# docker

.PHONY: print-image-name
print-image-name:  # Print '${DOCKER_IMAGE}:${IMAGE_TAG}'
	@echo ${DOCKER_IMAGE}:${IMAGE_TAG}
