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

# Global variables
SEPARATOR="---"
INCLUDE_EXTENSIONS=""
EXCLUDE_EXTENSIONS=""
printf -v COLOR_RESET '\e[0m'
printf -v COLOR_GREEN '\e[32m'
printf -v COLOR_YELLOW '\e[33m'

# Helper functions

usage() {
  echo "Usage: $0 [options] [source]"
  echo "       If no source option (-g or -d) is given, defaults to Git diff for the current branch (HEAD)."
  echo
  echo "Options:"
  echo "  -g <revision_or_range>    Get modified files. Can be a single revision/branch (diffs from merge-base)"
  echo "                            or a range like rev1..rev2. Defaults to HEAD if no source given."
  echo "  -d <directory>            Get all files from a directory (recursive)."
  echo "  -i <extensions>           Include only files with these extensions (comma-separated). Example: -i py,js,html"
  echo "  -e <extensions>           Exclude files with these extensions."
  echo "  -s <separator>            Separator between files (default: ---)."
  echo "  -r                        Dry run: show files that would be copied."
  echo "  -h                        Show help."
  return 1
}

# Function to get relative path, starting from the closest parent with .git or from home.
get_relative_path() {
  local file_path="$1"
  local git_root=""
  local relative_path=""

  # Find the .git root
  git_root=$(
    cd "$(dirname "$file_path")" 2>/dev/null &&
      git rev-parse --show-toplevel 2>/dev/null
  )

  if [[ -n "$git_root" ]]; then
    # Use realpath to resolve potential symlinks/../ before removing prefix
    relative_path=$(realpath --relative-to="$git_root" "$file_path" 2>/dev/null)
    # Fallback if realpath fails or not available
    if [[ -z "$relative_path" || $? -ne 0 ]]; then
      relative_path="${file_path#"$git_root/"}"
    fi
    echo "$relative_path"
  else
    # Use realpath to resolve potential symlinks/../ before removing prefix
    relative_path=$(realpath --relative-to="$HOME" "$file_path" 2>/dev/null)
    # Fallback if realpath fails or not available
    if [[ -z "$relative_path" || $? -ne 0 ]]; then
      relative_path="${file_path#"$HOME/"}"
    fi
    echo "$relative_path"
  fi
}

# Function to check if a file is binary
is_binary_file() {
  local file_path="$1"
  # Check if file exists and is readable before proceeding
  if [[ ! -r "$file_path" ]]; then
    echo "Warning: Cannot read file '$file_path', skipping." >&2
    return 0 # Treat as binary/unreadable
  fi
  # Use file command to check MIME type
  if file -b --mime-type "$file_path" | grep -q "^text/"; then
    return 1 # Not a binary file (exit code 1 for "false" in shell tests)
  else
    return 0 # Binary file (exit code 0 for "true")
  fi
}

# Function to get modified files in Git
get_git_modified_files() {
  local revisions="$1"
  local base_branch=""

  # Check if a revision range (a..b) was provided
  if [[ ! "$revisions" =~ \.\. ]]; then
    # This block handles the case where only ONE revision (e.g., a branch name or HEAD) is provided

    # Store the original single revision name provided by the user
    local target_revision="$revisions"

    # 1. Determine the primary "base" branch (master, main, or develop)
    #    Check if these branches actually exist before trying to use them
    base_branch=$( (git rev-parse --verify --quiet master ||
      git rev-parse --verify --quiet main ||
      git rev-parse --verify --quiet develop) 2>/dev/null)

    if [[ -z "$base_branch" ]]; then
      echo "Error: Could not determine a default base branch (master, main, or develop) that exists." >&2
      return 1
    fi

    # 2. Find the merge base (common ancestor) between the determined base branch
    #    and the user-specified target revision.
    local merge_base=$(git merge-base "$base_branch" "$target_revision" 2>/dev/null)

    if [[ -z "$merge_base" ]]; then
      # This can happen if the target branch has no common history with the base branch found
      echo "Error: Could not determine merge base between '$base_branch' and '$target_revision'." >&2
      # Optional: You might want a fallback here, like comparing base_branch..target_revision
      # echo "Warning: Falling back to comparing '$base_branch' directly with '$target_revision'." >&2
      # revisions="$base_branch..$target_revision"
      # For now, we strictly follow the request and error out if merge-base isn't found
      return 1
    fi

    # Check if merge_base is the same as target_revision (means no diff)
    if [[ "$(git rev-parse "$merge_base")" == "$(git rev-parse "$target_revision")" ]]; then
      echo "Info: Target revision '$target_revision' and merge base '$base_branch' ($merge_base) are the same. No changes." >&2
      # Return success, but empty list
      return 0
    fi

    # 3. Set the 'revisions' variable to compare the merge base with the target revision
    revisions="$merge_base..$target_revision"

  # If a range (a..b) was provided initially, 'revisions' already holds that range
  # and the 'if' block above is skipped.
  fi

  # Get the list of modified files using the final 'revisions' range (either a..b or merge_base..target_revision)
  # Excludes deleted files (D) and includes Added (A), Copied (C), Modified (M), Renamed (R), Type changed (T)
  git diff --name-only --diff-filter=ACMRT "$revisions"
}

# Function to get files from a directory
get_files_from_directory() {
  local directory="$1"

  # Check if the directory exists
  if [[ ! -d "$directory" ]]; then
    echo "Error: The directory '$directory' does not exist." >&2
    return 1
  fi

  # Use find to get all files (recursively)
  # -print0 and read -d '' handle filenames with spaces/newlines safely
  local find_cmd=(find "$directory" -type f -print0)
  local found_files=()
  while IFS= read -r -d $'\0' file; do
    found_files+=("$file")
  done < <("${find_cmd[@]}")
  printf "%s\n" "${found_files[@]}"

}

# Main function
copy_code() {
  local OPTIND=1
  local git_revisions="" # Changed default to empty
  local directory=""
  local include_extensions=""
  local exclude_extensions=""
  local separator="$SEPARATOR"
  local output=""
  local source_specified=false # Flag to track if -g or -d was used

  # Parse arguments
  local dry_run=false
  # Merged -g and -G into just g:
  while getopts "g:d:i:e:s:hr" opt; do
    case "$opt" in
    g)
      git_revisions="$OPTARG"
      source_specified=true
      ;; # Set flag
    d)
      directory="$OPTARG"
      source_specified=true
      ;; # Set flag
    i) INCLUDE_EXTENSIONS="$OPTARG" ;;
    e) EXCLUDE_EXTENSIONS="$OPTARG" ;;
    s) SEPARATOR="$OPTARG" ;;
    h)
      usage
      return 0
      ;; # Changed to return 0 after usage
    r) dry_run=true ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      return 1 # Return error for invalid option
      ;;
    esac
  done
  shift $((OPTIND - 1))

  # --- Default Behavior Logic ---
  # If no source flag was used, default to Git HEAD
  if [[ "$source_specified" == false ]]; then
    # Check if we are inside a git repository before defaulting
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Info: No source specified, defaulting to Git diff for current branch (HEAD)." >&2
      git_revisions="HEAD"
    else
      echo "Error: No source specified (-g or -d) and not inside a Git repository." >&2
      usage
      return 1
    fi
  fi
  # --- End Default Behavior Logic ---

  # Source verification (only relevant if both flags were somehow set, which getopts prevents)
  # This check is somewhat redundant now but harmless.
  if [[ -n "$git_revisions" && -n "$directory" ]]; then
    echo "Error: Specify either a Git revision (-g) or a directory (-d), not both." >&2
    usage
    return 1
  fi

  # Get the list of files
  local files_list=""
  local files=() # Initialize as an array
  local exit_code=0

  if [[ -n "$git_revisions" ]]; then
    # Ensure we are in a git repo before calling git functions
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Error: -g specified, but not inside a Git repository." >&2
      return 1
    fi
    files_list=$(get_git_modified_files "$git_revisions")
    exit_code=$?
    # Read the list into an array, handling potential newlines in output
    mapfile -t files <<<"$files_list"
    # Remove empty elements that might result from mapfile if input is empty
    files=("${files[@]}")

  elif [[ -n "$directory" ]]; then
    files_list=$(get_files_from_directory "$directory")
    exit_code=$?
    # Read the list into an array, handling potential newlines in output
    mapfile -t files <<<"$files_list"
    # Remove empty elements
    files=("${files[@]}")

  else
    # This case should not be reached due to default logic, but included for safety
    echo "Internal Error: No source determined." >&2
    return 1
  fi

  # Check exit code from file gathering functions
  if [[ $exit_code -ne 0 ]]; then
    echo "Error occurred while getting file list." >&2
    return 1 # Return error
  fi

  # Handle case where no files were found
  if [[ ${#files[@]} -eq 0 && -z "$files_list" ]]; then
    # Check if it was explicitly empty (e.g., git diff returned nothing) or an error
    if [[ $exit_code -eq 0 ]]; then
      echo "Info: No files found matching the criteria." >&2
      return 0 # Success, but nothing to do
    else
      # Error already reported by the called function
      return 1
    fi
  fi

  # Filter files
  local filtered_files=()
  for file in "${files[@]}"; do
    # Skip empty lines if any crept in
    [[ -z "$file" ]] && continue

    # Check if file actually exists (relevant for git diff if file was moved/deleted between diff and now)
    if [[ ! -f "$file" ]]; then
      echo "Warning: File '$file' listed but not found, skipping." >&2
      continue
    fi

    local extension="${file##*.}"

    # Check if the file is binary
    if is_binary_file "$file"; then
      if [[ "$dry_run" == true ]]; then
        printf "${COLOR_YELLOW}Would skip (binary):${COLOR_RESET} %s\n" "$file"
      fi
      continue # Skip binary files
    fi

    # Extension filtering (inclusion)
    if [[ -n "$INCLUDE_EXTENSIONS" ]]; then
      local include=false
      # Convert comma list to space list for loop
      local IFS=','
      for ext in $INCLUDE_EXTENSIONS; do
        # Trim whitespace around extension if user adds spaces like "py, js"
        ext=$(echo "$ext" | xargs) # xargs trims leading/trailing whitespace
        if [[ "$extension" == "$ext" ]]; then
          include=true
          break
        fi
      done
      unset IFS # Reset IFS
      if [[ "$include" == false ]]; then
        if [[ "$dry_run" == true ]]; then
          printf "${COLOR_YELLOW}Would skip (include filter):${COLOR_RESET} %s\n" "$file"
        fi
        continue
      fi
    fi

    # Extension filtering (exclusion)
    if [[ -n "$EXCLUDE_EXTENSIONS" ]]; then
      local exclude=false
      # Convert comma list to space list for loop
      local IFS=','
      for ext in $EXCLUDE_EXTENSIONS; do
        # Trim whitespace
        ext=$(echo "$ext" | xargs)
        if [[ "$extension" == "$ext" ]]; then
          exclude=true
          break
        fi
      done
      unset IFS # Reset IFS
      if [[ "$exclude" == true ]]; then
        if [[ "$dry_run" == true ]]; then
          printf "${COLOR_YELLOW}Would skip (exclude filter):${COLOR_RESET} %s\n" "$file"
        fi
        continue
      fi
    fi

    filtered_files+=("$file")

  done # End filtering loop

  # Handle case where filtering removed all files
  if [[ ${#filtered_files[@]} -eq 0 ]]; then
    echo "Info: No non-binary files found matching the criteria after filtering." >&2
    return 0 # Success, but nothing to copy
  fi

  # Build the output string
  for file in "${filtered_files[@]}"; do
    local relative_path=$(get_relative_path "$file")
    if [[ "$dry_run" == true ]]; then
      printf "${COLOR_GREEN}Would copy:${COLOR_RESET} %s\n" "$relative_path"
    else
      # Check if file is readable one last time before cat
      if [[ -r "$file" ]]; then
        output+="--- File: ${relative_path} ---\n"
        output+="$(cat "$file")"
        output+="\n${SEPARATOR}\n"
      else
        echo "Warning: Cannot read file '$relative_path' just before copying, skipping." >&2
      fi
    fi
  done

  # Copy to clipboard using xclip or print to stdout
  if [[ "$dry_run" == false ]]; then
    if command -v xclip &>/dev/null; then
      if [[ -n "$output" ]]; then
        echo -n "$output" | xclip -sel clipboard
        echo "Code copied to clipboard."
      else
        echo "Info: No content generated to copy." >&2
      fi
    else
      echo "Warning: xclip not found. Printing to stdout instead." >&2
      # Only print if there's actual output
      if [[ -n "$output" ]]; then
        echo "$output"
      else
        echo "Info: No content generated to print." >&2
      fi
    fi
  # else: Dry run messages were already printed
  fi

  return 0 # Indicate success
}

# Define the alias if the script is sourced
# It's generally better to put aliases in ~/.bashrc or ~/.zshrc
# but keeping it here based on previous state.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  alias cco="copy_code"
else
  # Allow direct execution for testing, call the main function
  copy_code "$@"
fi
