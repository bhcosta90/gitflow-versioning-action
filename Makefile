date:
	date '+%Y-%m-%d %H:%M:%S' > version
	git add version
	git commit -m 'feat: change version'
	git push

delete-tag:
	git fetch
	@if [ -z "$(version)" ]; then \
		echo "Error: You must specify the version as MAJOR.MINOR."; \
		exit 1; \
	fi
	@echo "Removing tags matching '$(version).0-*'..."
	@for tag in $(shell git tag -l "$(version).0-*"); do \
		git tag -d $$tag && git push origin --delete $$tag; \
	done
	@echo "All '$(version).*' tags have been removed."

help:
	@echo "  make date                   - Creates a version file with the current date and time"
	@echo "  make delete-tag version=0.0 - Removes tags matching 'dev-version.*' (e.g., 'dev-0.0.*')"
