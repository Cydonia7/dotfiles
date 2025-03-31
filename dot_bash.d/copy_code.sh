#!/bin/bash

# Description: Script to easily copy code snippets (Git, directories, etc.) optimized for LLMs.
# Usage: copy-code [options] [source]
#        If no source option (-g or -d) is given, defaults to Git diff for the current branch (HEAD).
#
# Options:
#   -g <revision_or_range>    Get modified files. Can be a single revision/branch (diffs from merge-base)
#                             or a range like rev1..rev2. Defaults to HEAD if no source given.
#   -d <directory>            Get all files from a directory (recursive).
#   -i <extensions>           Include only files with these extensions (comma-separated). Example: -i py,js,html
#   -e <extensions>           Exclude files with these extensions.
#   -s <separator>            Separator between files (default: ---).
#   -r                        Dry run: show files that would be copied.
#   -h                        Show help.

# --- Global Defaults ---
# These can be overridden by command-line options within the function's scope.
DEFAULT_SEPARATOR="---"
# Color definitions for dry run output
printf -v COLOR_RESET '\e[0m'
printf -v COLOR_GREEN '\e[32m'
printf -v COLOR_YELLOW '\e[33m'

# --- Helper Functions ---

usage() {
  # Provides usage instructions
  echo "Usage: $0 [options] [source]"
  echo "       If no source option (-g or -d) is given, defaults to Git diff for the current branch (HEAD)."
  echo
  echo "Options:"
  echo "  -g <revision_or_range>    Get modified files. Can be a single revision/branch (diffs from merge-base)"
  echo "                            or a range like rev1..rev2. Defaults to HEAD if no source given."
  echo "  -d <directory>            Get all files from a directory (recursive)."
  echo "  -i <extensions>           Include only files with these extensions (comma-separated). Example: -i py,js,html"
  echo "  -e <extensions>           Exclude files with these extensions."
  echo "  -s <separator>            Separator between files (default: '${DEFAULT_SEPARATOR}')."
  echo "  -r                        Dry run: show files that would be copied."
  echo "  -h                        Show help."
  return 1 # Indicate error for help request
}

get_relative_path() {
  # Calculates a relative path, preferring git root, falling back to HOME.
  local file_path="$1"
  local git_root=""
  local relative_path=""

  git_root=$(cd "$(dirname "$file_path")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)

  if [[ -n "$git_root" ]]; then
    relative_path=$(realpath --relative-to="$git_root" "$file_path" 2>/dev/null) || relative_path="${file_path#"$git_root/"}"
    echo "$relative_path"
  else
    relative_path=$(realpath --relative-to="$HOME" "$file_path" 2>/dev/null) || relative_path="${file_path#"$HOME/"}"
    echo "$relative_path"
  fi
}

is_binary_file() {
  # Checks if a file appears to be binary using grep -I (looks for null bytes).
  local file_path="$1"
  if [[ ! -r "$file_path" ]]; then
    echo "Warning: Cannot read file '$file_path', skipping." >&2
    return 0 # Treat unreadable as binary (true = 0)
  fi

  # grep -I exits 0 if file is text, 1 if binary/suppressed. We invert it.
  if ! grep -qI '' "$file_path"; then
    return 0 # Is binary (true = 0)
  else
    return 1 # Is text (false = 1)
  fi
}

get_git_modified_files() {
  # Retrieves list of modified files between Git revisions.
  local revisions="$1"
  local base_branch=""

  # Handle single revision: find merge-base with master/main/develop
  if [[ ! "$revisions" =~ \.\. ]]; then
    local target_revision="$revisions"
    base_branch=$( (git rev-parse --verify --quiet master ||
      git rev-parse --verify --quiet main ||
      git rev-parse --verify --quiet develop) 2>/dev/null)

    if [[ -z "$base_branch" ]]; then
      echo "Error: Could not determine a default base branch (master, main, or develop) that exists." >&2
      return 1
    fi

    local merge_base=$(git merge-base "$base_branch" "$target_revision" 2>/dev/null)
    if [[ -z "$merge_base" ]]; then
      echo "Error: Could not determine merge base between '$base_branch' and '$target_revision'." >&2
      return 1
    fi

    if [[ "$(git rev-parse "$merge_base")" == "$(git rev-parse "$target_revision")" ]]; then
      echo "Info: Target revision '$target_revision' and merge base '$base_branch' ($merge_base) are the same. No changes." >&2
      return 0 # Success, but empty list
    fi

    revisions="$merge_base..$target_revision"
  fi

  # Get Added, Copied, Modified, Renamed, Type-changed files
  git diff --name-only --diff-filter=ACMRT "$revisions"
}

get_files_from_directory() {
  # Finds all regular files recursively in a directory.
  local directory="$1"
  if [[ ! -d "$directory" ]]; then
    echo "Error: The directory '$directory' does not exist." >&2
    return 1
  fi

  # Use find with -print0 and mapfile for safety with special filenames
  local find_cmd=(find "$directory" -type f -print0)
  local -a found_files # Declare array explicitly
  mapfile -d '' -t found_files < <("${find_cmd[@]}")
  # Print one file per line for caller
  printf "%s\n" "${found_files[@]}"
}

# --- Main Function ---
copy_code() {
  # Reset getopts processing index for reliable option parsing on subsequent calls
  local OPTIND=1

  # Local variables for this function call, potentially overriding globals/defaults
  local git_revisions=""
  local directory=""
  local include_extensions=""
  local exclude_extensions=""
  local separator="${DEFAULT_SEPARATOR}" # Start with default
  local output=""
  local source_specified=false
  local dry_run=false

  # Parse command-line options specific to this call
  while getopts "g:d:i:e:s:hr" opt; do
    case "$opt" in
    g)
      git_revisions="$OPTARG"
      source_specified=true
      ;;
    d)
      directory="$OPTARG"
      source_specified=true
      ;;
    i) include_extensions="$OPTARG" ;;
    e) exclude_extensions="$OPTARG" ;;
    # ------------------------------------
    s) separator="$OPTARG" ;;
    h)
      usage
      return 0
      ;;
    r) dry_run=true ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      return 1
      ;;
    esac
  done
  shift $((OPTIND - 1)) # Remove processed options

  # Default to Git HEAD diff if no source (-g or -d) was specified
  if [[ "$source_specified" == false ]]; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Info: No source specified, defaulting to Git diff for current branch (HEAD)." >&2
      git_revisions="HEAD"
    else
      echo "Error: No source specified (-g or -d) and not inside a Git repository." >&2
      usage
      return 1
    fi
  fi

  # Sanity check: Ensure only one source type is effectively set
  if [[ -n "$git_revisions" && -n "$directory" ]]; then
    echo "Error: Specify either a Git revision (-g) or a directory (-d), not both." >&2
    usage
    return 1
  fi

  # Get the initial list of files based on the source
  local files_list=""
  local -a files=() # Use local array
  local exit_code=0

  if [[ -n "$git_revisions" ]]; then
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Error: -g specified, but not inside a Git repository." >&2
      return 1
    fi
    files_list=$(get_git_modified_files "$git_revisions")
    exit_code=$?
    mapfile -t files <<<"$files_list" # Read list into array

  elif [[ -n "$directory" ]]; then
    files_list=$(get_files_from_directory "$directory")
    exit_code=$?
    mapfile -t files <<<"$files_list" # Read list into array
  else
    echo "Internal Error: No source determined." >&2
    return 1 # Should not happen
  fi

  # Handle errors during file list retrieval
  if [[ $exit_code -ne 0 ]]; then
    echo "Error occurred while getting file list." >&2
    return 1
  fi

  # Handle empty initial file list (not an error, just nothing found)
  if [[ ${#files[@]} -eq 0 && -z "$files_list" ]]; then
    echo "Info: No files found matching the initial criteria." >&2
    return 0
  fi

  # --- Filtering Logic ---
  local -a filtered_files=() # Use local array
  for file in "${files[@]}"; do
    [[ -z "$file" ]] && continue # Skip empty entries if any
    if [[ ! -f "$file" ]]; then  # Check if file exists now
      echo "Warning: File '$file' listed but not found, skipping." >&2
      continue
    fi

    local extension="${file##*.}"

    # Binary file check
    if is_binary_file "$file"; then
      [[ "$dry_run" == true ]] && printf "${COLOR_YELLOW}Would skip (binary):${COLOR_RESET} %s\n" "$file"
      continue
    fi

    # Include filter check (uses local include_extensions)
    if [[ -n "$include_extensions" ]]; then
      local include=false
      local IFS=','
      for ext in $include_extensions; do
        ext=$(echo "$ext" | xargs) # Trim whitespace
        if [[ "$extension" == "$ext" ]]; then
          include=true
          break
        fi
      done
      unset IFS
      if [[ "$include" == false ]]; then
        [[ "$dry_run" == true ]] && printf "${COLOR_YELLOW}Would skip (include filter):${COLOR_RESET} %s\n" "$file"
        continue
      fi
    fi

    # Exclude filter check (uses local exclude_extensions)
    if [[ -n "$exclude_extensions" ]]; then
      local exclude=false
      local IFS=','
      for ext in $exclude_extensions; do
        ext=$(echo "$ext" | xargs) # Trim whitespace
        if [[ "$extension" == "$ext" ]]; then
          exclude=true
          break
        fi
      done
      unset IFS
      if [[ "$exclude" == true ]]; then
        [[ "$dry_run" == true ]] && printf "${COLOR_YELLOW}Would skip (exclude filter):${COLOR_RESET} %s\n" "$file"
        continue
      fi
    fi

    # If we passed all checks, add to the final list
    filtered_files+=("$file")
  done

  # Handle case where filtering removed all files
  if [[ ${#filtered_files[@]} -eq 0 ]]; then
    echo "Info: No non-binary files found matching the criteria after filtering." >&2
    return 0
  fi

  # --- Output Generation or Dry Run ---
  for file in "${filtered_files[@]}"; do
    local relative_path
    relative_path=$(get_relative_path "$file")

    if [[ "$dry_run" == true ]]; then
      printf "${COLOR_GREEN}Would copy:${COLOR_RESET} %s\n" "$relative_path"
    else
      if [[ -r "$file" ]]; then
        output+="--- File: ${relative_path} ---"
        output+=$'\n'
        output+="$(cat "$file")"
        output+=$'\n'"${separator}"$'\n'
      else
        echo "Warning: Cannot read file '$relative_path' just before copying, skipping." >&2
      fi
    fi
  done

  # Copy to clipboard or print to stdout if not dry run
  if [[ "$dry_run" == false ]]; then
    if command -v xclip &>/dev/null; then
      if [[ -n "$output" ]]; then
        echo -n "$output" | xclip -sel clipboard
        echo "Code copied to clipboard."
      else
        echo "Info: No content generated to copy." >&2 # Should not happen if filtering logic is correct
      fi
    else
      echo "Warning: xclip not found. Printing to stdout instead." >&2
      if [[ -n "$output" ]]; then echo "$output"; else echo "Info: No content generated to print." >&2; fi
    fi
  fi

  return 0 # Indicate overall success
}

# --- Execution / Alias Definition ---

# Define the alias if the script is sourced (e.g., from .bashrc)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  alias cco="copy_code"
else
  # Allow direct execution (e.g., ./copy-code -g HEAD), calls the main function
  copy_code "$@"
fi
