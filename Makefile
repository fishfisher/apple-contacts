.PHONY: build clean release skill dist

build:
	swift build

release:
	swift build -c release

clean:
	rm -rf .build/
	rm -rf dist/

# Regenerate the skill embedded in the binary from apple-contacts-skill/SKILL.md.
skill:
	{ echo '// Auto-generated from apple-contacts-skill/SKILL.md by `make skill`.'; \
	  echo '// Do not edit directly.'; echo; \
	  echo 'enum EmbeddedSkill {'; \
	  echo '    static let skillMD = #"""'; \
	  cat apple-contacts-skill/SKILL.md; echo; \
	  echo '"""#'; echo '}'; } > Sources/EmbeddedSkill.swift

# Release zip for `gh release create` (installed with `fishtools install apple-contacts`).
dist: skill release
	rm -rf dist && mkdir -p dist
	cp .build/release/apple-contacts dist/
	cd dist && zip -q apple-contacts-darwin-arm64.zip apple-contacts
	shasum -a 256 dist/apple-contacts-darwin-arm64.zip
