REPO_URL = https://raw.githubusercontent.com/alexbornovo-svg/PXScript/main/interpreter.ru
INSTALL_PATH = /usr/local/bin/pxscript

.PHONY: install update uninstall

install:
	@echo "Downloading PXScript..."
	@curl -fsSL $(REPO_URL) -o $(INSTALL_PATH)
	@chmod +x $(INSTALL_PATH)
	@echo "Installed in $(INSTALL_PATH)"

update: install
	@echo "Updated to latest version."

uninstall:
	@rm -f $(INSTALL_PATH)
	@echo "PXScript removed."