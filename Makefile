
# This Makefile is, for the most part, a wrapper around the scripts in the ./scripts folder
# @link https://makefiletutorial.com/

-include .env

APP_NAME					= obsidian-plugin-template
BIN_FOR_APP					= dist/app.js
BIN_FOR_GIT					= git
BIN_FOR_NODE				= node
BIN_FOR_MADGE				= madge	
BIN_FOR_NPM					= npm
BIN_FOR_NPX					= npx
PATHS_THAT_ARE_EPHEMERAL	= dist coverage docs/graph.png
PATH_TO_SCRIPTS				= scripts
	PATH_FOR_ESBUILD_CONFIG		= $(PATH_TO_SCRIPTS)/esbuild.config.mjs
	PATH_FOR_GRAPH_PNG		 	= $(PATH_TO_DOCS)/graph.png

PATH_TO_COVERAGE			= coverage/index.html
PATH_TO_DIST				= dist
PATH_TO_DOCS				= docs

PATH_TO_PLUGINS				= $(OBSIDIAN_PLUGINS_PATH)/$(APP_NAME)


define title
	@echo "\n\033[1;33m🤖$(1)\033[0m"
endef

.PHONY: %

assume:
# Assume the project is set up.
# First, make sure `npm install` has been run.
	@$(BIN_FOR_NPM) list --depth=0 > /dev/null  || (echo "You are missing dependencies. Did you run 'npm install' first?" && exit 1)

huh: assume
# Get the name of the command.
# Print the command, followed by the comments below it, like this one!
	@$(BIN_FOR_NODE) $(PATH_TO_SCRIPTS)/makefile-parser.mjs --format=list

clean:
# Clean up ephemeral paths.
	$(call title, "Cleaning up ephemeral paths: $(PATHS_THAT_ARE_EPHEMERAL)")
	rm -rf $(PATHS_THAT_ARE_EPHEMERAL)

deep-clean: clean
# Clean up all the generated files.
# Also clean up node_modules and package-lock.json.
	$(call title, "Cleaning up all generated files")
	$(PATH_TO_SCRIPTS)/deep-clean.sh

build-manifest:
# Build the manifest file.
	$(call title, "Building the manifest file")
	cp manifest.json dist/manifest.json

build-styles:
# Compile the SASS file into CSS.
	$(call title, "Compiling SASS")
	$(BIN_FOR_NPX) sass src/styles.scss $(PATH_TO_DIST)/styles.css

build: build-styles build-manifest
# Build the app, dump into the dist folder.
	$(call title, "Building the app: $(BIN_FOR_APP)")
	$(BIN_FOR_NODE) $(PATH_FOR_ESBUILD_CONFIG) production

app: clean build
# Rebuild the app, then run it to get the output.
# This is a quick way to see the output of the app, and to sanity check the build.
	$(call title, "Running the app: $(BIN_FOR_APP)")
	@$(BIN_FOR_NODE) $(BIN_FOR_APP) | sed 's/^/> /'

test:
# Run the jest unit tests.
	$(call title, "Running tests")
	$(BIN_FOR_NPM) exec jest

test-coverage: clean
# Run the jest unit tests with coverage enabled.
# Then open the coverage report in the browser.
	$(call title, "Running tests with coverage")
	$(BIN_FOR_NPM) exec jest tests --coverage
	open $(PATH_TO_COVERAGE)

docs:
# Generate the documentation for the project.
	$(call title, "Generating documentation")
	$(BIN_FOR_NPX) typedoc --plugin typedoc-plugin-markdown --out $(PATH_TO_DOCS) src/index.ts

format:
# Format the code using prettier.
	$(call title, "Formatting code")
	$(BIN_FOR_NPX) prettier --write src/**/*.ts

install:
# Install the project dependencies.
	$(call title, "Installing dependencies")
	$(BIN_FOR_NPM) install
	$(BIN_FOR_NPM) install --location=global madge
	$(BIN_FOR_NPX) husky init
	echo "make pre-commit" > .husky/pre-commit

install-husky:
# Install husky if it's not already installed.
	$(call title, "Installing husky if needed")
	@$(BIN_FOR_NPM) install --save-dev husky
	$(BIN_FOR_NPX) husky init

install-madge:
# Install madge if it's not already installed.
	$(call title, "Installing madge if needed")
	@$(BIN_FOR_NPM) list -g madge || $(BIN_FOR_NPM) install --location=global madge

lint: format
# Lint the code using eslint.
	$(call title, "Linting code")
	$(BIN_FOR_NPX) eslint src/**/*.ts

lint-fix: format
# Lint the code using eslint, and fix the issues.
	$(call title, "Linting code and fixing issues")
	$(BIN_FOR_NPX) eslint src/**/*.ts --fix

pre-commit: lint-fix test
# Run the pre-commit checks.
	$(call title, "Running pre-commit checks")

rename: assume clean
# Rename the project.
	$(call title, "Renaming the project")
	$(BIN_FOR_NODE) $(PATH_TO_SCRIPTS)/rename-project.mjs

visualize-circular-dependencies: 
# Visualize the circular dependencies in the project.
	$(call title, "Visualizing circular dependencies")
	@$(BIN_FOR_MADGE) --circular --extensions ts src

visualize-dependencies:
# Visualize the dependencies in the project.
	$(call title, "Visualizing dependencies")
	@$(BIN_FOR_MADGE) --extensions ts src

visualize-dependencies-graph:
# Visualize the dependencies in the project as a graph.
	$(call title, "Visualizing dependencies as a graph")
	mkdir -p $$(dirname $(PATH_FOR_GRAPH_PNG))
	@$(BIN_FOR_MADGE) --extensions ts src --image $(PATH_FOR_GRAPH_PNG)
	open $(PATH_FOR_GRAPH_PNG)

watch-styles:
# Watch the SASS file and compile it into CSS.
	$(call title, "Watching SASS")
	$(BIN_FOR_NPX) sass --watch src/styles.scss $(PATH_TO_DIST)/styles.css

watch: 
# Watch the app and rebuild it on changes.
	$(call title, "Watching the app")
	$(BIN_FOR_NODE) $(PATH_FOR_ESBUILD_CONFIG) development --watch

changelog:
# Generate the changelog for the project.
	$(call title, "Generating changelog")
	$(BIN_FOR_NPX) auto-changelog -p -o CHANGELOG.md --hide-credit --release-summary --hide-empty-releases --sort-commits date-desc && git add CHANGELOG.md

env:
# Move `.env-example` to `.env`.
	$(call title, "Moving .env-example to .env")
	cp .env-example .env

release:
# Release the project.
	$(call title, "Releasing the project")
	$(BIN_FOR_NPM) exec node $(PATH_TO_SCRIPTS)/version-bump.mjs || exit 1
	$(BIN_FOR_GIT) add manifest.json versions.json

link:
# Link the project to the Obsidian plugins folder.
	$(call title, "Linking the project to the Obsidian plugins folder")
	mkdir -p $(OBSIDIAN_PLUGINS_PATH)/$(APP_NAME)
	rm -rf $(OBSIDIAN_PLUGINS_PATH)/$(APP_NAME)
	ln -s $(PWD)/$(PATH_TO_DIST)/ $(OBSIDIAN_PLUGINS_PATH)/$(APP_NAME)
