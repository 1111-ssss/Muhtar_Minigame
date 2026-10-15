.PHONY: test analyze format run build publish-maps

test analyze format run build publish-maps:
	$(MAKE) --no-print-directory -C muhtar_minigame $@
