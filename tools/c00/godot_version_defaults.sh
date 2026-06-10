#!/usr/bin/env bash

C00_GODOT_LATEST_TAG="${C00_GODOT_LATEST_TAG:-4.7-rc1}"
C00_GODOT_LATEST_EXPORT_TEMPLATES_VERSION="${C00_GODOT_LATEST_EXPORT_TEMPLATES_VERSION:-4.7.rc1}"
C00_GODOT_STABLE_TAG="${C00_GODOT_STABLE_TAG:-4.6.3-stable}"
C00_GODOT_STABLE_EXPORT_TEMPLATES_VERSION="${C00_GODOT_STABLE_EXPORT_TEMPLATES_VERSION:-4.6.3.stable}"
C00_GODOT_DEFAULT_TAG="${C00_GODOT_DEFAULT_TAG:-$C00_GODOT_LATEST_TAG}"
C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION="${C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION:-$C00_GODOT_LATEST_EXPORT_TEMPLATES_VERSION}"

godot_normalize_template_version() {
	local value="$1"
	case "$value" in
		*.stable|*.rc[0-9]*|*.beta[0-9]*|*.dev[0-9]*)
			printf "%s" "$value"
			;;
		*-stable)
			printf "%s.stable" "${value%-stable}"
			;;
		*-rc[0-9]*|*-beta[0-9]*|*-dev[0-9]*)
			local suffix
			suffix="${value##*-}"
			printf "%s.%s" "${value%-"$suffix"}" "$suffix"
			;;
		[0-9]*.[0-9]*.[0-9]*)
			printf "%s.stable" "$value"
			;;
		*)
			printf "%s" "$value"
			;;
	esac
}

godot_tag_from_template_version() {
	local version base suffix
	version="$(godot_normalize_template_version "$1")"
	case "$version" in
		*.stable)
			printf "%s-stable" "${version%.stable}"
			;;
		*.rc[0-9]*)
			base="${version%.rc*}"
			suffix="rc${version##*.rc}"
			printf "%s-%s" "$base" "$suffix"
			;;
		*.beta[0-9]*)
			base="${version%.beta*}"
			suffix="beta${version##*.beta}"
			printf "%s-%s" "$base" "$suffix"
			;;
		*.dev[0-9]*)
			base="${version%.dev*}"
			suffix="dev${version##*.dev}"
			printf "%s-%s" "$base" "$suffix"
			;;
		*)
			printf "%s" "$version"
			;;
	esac
}

godot_template_version_from_tag() {
	godot_normalize_template_version "$1"
}

godot_download_flavor_from_template_version() {
	local version
	version="$(godot_normalize_template_version "$1")"
	case "$version" in
		*.stable) printf "stable" ;;
		*.rc[0-9]*) printf "rc%s" "${version##*.rc}" ;;
		*.beta[0-9]*) printf "beta%s" "${version##*.beta}" ;;
		*.dev[0-9]*) printf "dev%s" "${version##*.dev}" ;;
		*) printf "stable" ;;
	esac
}

godot_download_version_number_from_template_version() {
	local version
	version="$(godot_normalize_template_version "$1")"
	case "$version" in
		*.stable) printf "%s" "${version%.stable}" ;;
		*.rc[0-9]*) printf "%s" "${version%.rc*}" ;;
		*.beta[0-9]*) printf "%s" "${version%.beta*}" ;;
		*.dev[0-9]*) printf "%s" "${version%.dev*}" ;;
		*) printf "%s" "$version" ;;
	esac
}

godot_official_download_url_from_template_version() {
	local version
	version="$(godot_normalize_template_version "$1")"
	printf "https://downloads.godotengine.org/?flavor=%s&platform=templates&slug=export_templates.tpz&version=%s" \
		"$(godot_download_flavor_from_template_version "$version")" \
		"$(godot_download_version_number_from_template_version "$version")"
}
