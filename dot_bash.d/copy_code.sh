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
  echo "  -w <work_dir>             Specify a working directory to process. Can specify multiple with comma."
  echo "                            If used, -g and -d apply within each work_dir."
  echo "  -i <extensions>           Include only files with these extensions (comma-separated). Example: -i py,js,html"
  echo "  -e <extensions>           Exclude files with these extensions (comma-separated)."
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
# --- Main Function ---
copy_code() {
  # Reset getopts processing index for reliable option parsing on subsequent calls
  local OPTIND=1

  # Local variables for this function call, potentially overriding globals/defaults
  local GIT_REVISIONS_GLOBAL="" # Renamed to clarify it's the global option
  local DIRECTORY_GLOBAL=""     # Renamed to clarify it's the global option
  local -a WORK_DIRS=()
  local used_w_option=false
  local ORIGINAL_CWD=""

  local include_extensions=""
  local exclude_extensions=""
  local separator="${DEFAULT_SEPARATOR}"
  local output=""
  local source_specified_globally=false # Tracks if -g or -d was specified globally
  local dry_run=false

  ORIGINAL_CWD=$(pwd)

  while getopts "g:d:w:i:e:s:hr" opt; do
    case "$opt" in
    g)
      GIT_REVISIONS_GLOBAL="$OPTARG"
      source_specified_globally=true
      ;;
    d)
      DIRECTORY_GLOBAL="$OPTARG"
      source_specified_globally=true
      ;;
    w)
      local old_ifs="$IFS"
      IFS=','
      local single_w_arg="$OPTARG"      # Store OPTARG before it's clobbered by the loop
      for dir_path in $single_w_arg; do # Split the argument from -w by comma
        # Trim whitespace from individual dir_path
        local trimmed_dir_path
        trimmed_dir_path=$(echo "$dir_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$trimmed_dir_path" ]]; then # Add to WORK_DIRS if not empty
          WORK_DIRS+=("$trimmed_dir_path")
        fi
      done
      IFS="$old_ifs"
      used_w_option=true
      ;;
    i) include_extensions="$OPTARG" ;;
    e) exclude_extensions="$OPTARG" ;;
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
  shift $((OPTIND - 1))

  # Sanity check: Ensure only one global source type is specified
  if [[ -n "$GIT_REVISIONS_GLOBAL" && -n "$DIRECTORY_GLOBAL" ]]; then
    echo "Error: Specify either a global Git revision (-g) or a global directory (-d), not both." >&2
    usage
    return 1
  fi

  local -a actual_work_dirs_to_process=()
  if [[ "${#WORK_DIRS[@]}" -gt 0 ]]; then
    actual_work_dirs_to_process=("${WORK_DIRS[@]}")
  else
    actual_work_dirs_to_process=(".")
  fi

  # --- Main Loop for Working Directories ---
  local -a all_collected_files=() # Array to hold all files from all work_dirs

  for wd_rel_path_input in "${actual_work_dirs_to_process[@]}"; do
    # Resolve the working directory path relative to ORIGINAL_CWD
    # Using -m to allow non-existent paths for now, error handled below
    local wd_abs_path
    wd_abs_path=$(realpath -m "$ORIGINAL_CWD/$wd_rel_path_input" 2>/dev/null)

    if [[ ! -d "$wd_abs_path" ]]; then
      echo "Warning: Working directory '$wd_rel_path_input' (resolved to '$wd_abs_path') not found or not a directory. Skipping." >&2
      continue
    fi

    # Use a subshell for cd to avoid pushd/popd complexities with error handling here
    # or manage pushd/popd carefully. Let's try subshell first for simplicity.
    # Subshell output needs to be captured.

    # Alternative using pushd/popd for more direct control if subshell gets complex with return values
    if ! pushd "$wd_abs_path" >/dev/null; then
      echo "Error: Could not change to directory '$wd_abs_path'. Skipping." >&2
      continue
    fi

    local files_list_segment=""
    local exit_code_segment=0
    local current_source_is_git=false
    local current_source_is_dir=false
    local effective_git_revisions="$GIT_REVISIONS_GLOBAL"
    local effective_directory="$DIRECTORY_GLOBAL"

    # Determine source for this specific working directory
    if [[ -n "$GIT_REVISIONS_GLOBAL" ]]; then
      current_source_is_git=true
    elif [[ -n "$DIRECTORY_GLOBAL" ]]; then
      current_source_is_dir=true
    else # No global -g or -d, default to Git HEAD for this wd
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        effective_git_revisions="HEAD"
        current_source_is_git=true
        # Don't echo info here, it's per-wd, might be noisy.
        # Could add a verbose mode later if needed.
      else
        # If not a git repo and no -d global, there's nothing to do for this wd by default
        if [[ "$used_w_option" == true ]]; then # Only warn if -w was explicitly used
          echo "Info: Working directory '$wd_rel_path_input' is not a Git repository and no -d source specified. Nothing to process by default." >&2
        else # If not using -w (so processing '.'), and it's not a git repo, and no -d.
          # This case is similar to the original script's error.
          echo "Error: No source specified (-g or -d) and current directory '$wd_rel_path_input' is not a Git repository." >&2
          # If only one "work_dir" ('.') and it fails like this, the whole script might as well fail.
          if [[ ${#actual_work_dirs_to_process[@]} -eq 1 ]]; then
            popd >/dev/null
            usage
            return 1
          fi
        fi
        popd >/dev/null
        continue
      fi
    fi

    # Get the initial list of files based on the determined source for this wd
    local -a files_segment_arr=()

    if [[ "$current_source_is_git" == true ]]; then
      if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Warning: Git source specified for '$wd_rel_path_input', but it's not a Git repository. Skipping." >&2
        popd >/dev/null
        continue
      fi
      files_list_segment=$(get_git_modified_files "$effective_git_revisions")
      exit_code_segment=$?
      mapfile -t files_segment_arr <<<"$files_list_segment"

    elif [[ "$current_source_is_dir" == true ]]; then
      # effective_directory path is relative to the current wd_abs_path
      if [[ ! -d "$effective_directory" ]]; then
        echo "Warning: Source directory '$effective_directory' not found within '$wd_rel_path_input'. Skipping." >&2
        popd >/dev/null
        continue
      fi
      files_list_segment=$(get_files_from_directory "$effective_directory")
      exit_code_segment=$?
      mapfile -t files_segment_arr <<<"$files_list_segment"
    fi

    if [[ $exit_code_segment -ne 0 ]]; then
      echo "Warning: Error occurred while getting file list for '$wd_rel_path_input'. Skipping." >&2
      popd >/dev/null
      continue
    fi

    if [[ ${#files_segment_arr[@]} -eq 0 && -z "$files_list_segment" ]]; then
      # This is not an error, just no files found for this segment
      # echo "Info: No files found for '$wd_rel_path_input' with current criteria." >&2
      popd >/dev/null
      continue
    fi

    # Prefix files with wd_rel_path_input (if not ".") and add to all_collected_files
    for file_in_wd in "${files_segment_arr[@]}"; do
      [[ -z "$file_in_wd" ]] && continue # Skip empty lines
      local prefixed_file_path
      if [[ "$wd_rel_path_input" == "." ]]; then
        prefixed_file_path="$file_in_wd"
      else
        # Ensure no double slashes if wd_rel_path_input ends with / and file_in_wd starts with / (though find/git shouldn't do that)
        prefixed_file_path="${wd_rel_path_input%/}/${file_in_wd}"
      fi
      # Normalize the path to remove ./ and ../ components if any are introduced
      # This normalization should happen relative to ORIGINAL_CWD
      local normalized_path
      normalized_path=$(realpath -m --relative-to="$ORIGINAL_CWD" "$ORIGINAL_CWD/$prefixed_file_path")
      all_collected_files+=("$normalized_path")
    done

    popd >/dev/null # Return from wd_abs_path
  done              # End of main loop for working directories

  # --- At this point, all_collected_files contains all paths relative to ORIGINAL_CWD ---
  # --- The rest of the script (filtering, output) will operate on all_collected_files ---

  # Remove the temporary test output from Phase 1
  # if [[ "$dry_run" == true || "$used_w_option" == true ]]; then ... fi

  # Check if any files were collected overall
  if [[ ${#all_collected_files[@]} -eq 0 ]]; then
    echo "Info: No files found matching the criteria across all specified working directories." >&2
    return 0
  fi

  # --- Filtering Logic (operates on all_collected_files) ---
  # We now use 'all_collected_files' instead of 'files'
  local -a filtered_files=()
  for file in "${all_collected_files[@]}"; do # Iterate over the globally collected files
    [[ -z "$file" ]] && continue

    # Check file existence using path relative to ORIGINAL_CWD
    # This needs to be file_abs_path for is_binary and extension checks.
    # The 'file' variable is already relative to ORIGINAL_CWD.
    local file_to_check_abs_path="$ORIGINAL_CWD/$file"

    if [[ ! -f "$file_to_check_abs_path" ]]; then
      echo "Warning: File '$file' (resolved to '$file_to_check_abs_path') listed but not found, skipping." >&2
      continue
    fi

    local extension="${file##*.}" # Extension from the path relative to ORIGINAL_CWD

    # Binary file check (needs absolute path or path relative to current CWD)
    if is_binary_file "$file_to_check_abs_path"; then
      [[ "$dry_run" == true ]] && printf "${COLOR_YELLOW}Would skip (binary):${COLOR_RESET} %s\n" "$file" # Display relative path
      continue
    fi

    # Include filter check
    if [[ -n "$include_extensions" ]]; then
      local include=false
      # Save original IFS and set to comma for splitting
      local old_ifs="$IFS"
      IFS=','
      for ext_pattern in $include_extensions; do # Now $include_extensions is split by comma
        # Trim whitespace from individual ext_pattern
        ext_pattern=$(echo "$ext_pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # More robust trim
        if [[ -n "$ext_pattern" && "$extension" == "$ext_pattern" ]]; then             # Check if ext_pattern is not empty
          include=true
          break
        fi
      done
      IFS="$old_ifs" # Restore original IFS
      if [[ "$include" == false ]]; then
        [[ "$dry_run" == true ]] && printf "${COLOR_YELLOW}Would skip (include filter):${COLOR_RESET} %s\n" "$file"
        continue
      fi
    fi

    # Exclude filter check
    if [[ -n "$exclude_extensions" ]]; then
      local exclude=false
      # Save original IFS and set to comma for splitting
      local old_ifs="$IFS"
      IFS=','
      for ext_pattern in $exclude_extensions; do # Now $exclude_extensions is split by comma
        # Trim whitespace from individual ext_pattern
        ext_pattern=$(echo "$ext_pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # More robust trim
        if [[ -n "$ext_pattern" && "$extension" == "$ext_pattern" ]]; then             # Check if ext_pattern is not empty
          exclude=true
          break
        fi
      done
      IFS="$old_ifs" # Restore original IFS
      if [[ "$exclude" == true ]]; then
        [[ "$dry_run" == true ]] && printf "${COLOR_YELLOW}Would skip (exclude filter):${COLOR_RESET} %s\n" "$file"
        continue
      fi
    fi

    filtered_files+=("$file")
  done

  if [[ ${#filtered_files[@]} -eq 0 ]]; then
    echo "Info: No non-binary files found matching the criteria after filtering." >&2
    return 0
  fi

  # --- Output Generation or Dry Run ---
  # The 'file' variable in this loop is already the path relative to ORIGINAL_CWD
  # which is what we want for the "File: ..." header when -w is used.
  local redact_regex="s/([a-zA-Z0-9_]*[Aa][Pp][Ii]\s*[Kk][Ee][Yy][a-zA-Z0-9_]*\s*[:=]\s*)(['\"])(.*?)\2([;,]?)/\1\2REDACTED\2\4/g"

  for file in "${filtered_files[@]}"; do
    # 'file' is already the path like 'repoA/file.txt' or 'file_in_root.txt'
    # The get_relative_path function will need adjustment in Phase 3 to handle this.
    # For Phase 2, we can temporarily just use 'file' for the header.
    local display_path="$file"

    if [[ "$dry_run" == true ]]; then
      printf "${COLOR_GREEN}Would copy:${COLOR_RESET} %s\n" "$display_path"
    else
      # We need the absolute path to cat the file
      local file_to_cat_abs_path="$ORIGINAL_CWD/$file"
      if [[ -r "$file_to_cat_abs_path" ]]; then
        output+="--- File: ${display_path} ---"
        output+=$'\n'
        # Ensure cat uses the correct absolute path
        output+="$(cat "$file_to_cat_abs_path" | sed -E "$redact_regex")"
        output+=$'\n'"${separator}"$'\n'
      else
        echo "Warning: Cannot read file '$display_path' (resolved to '$file_to_cat_abs_path') just before copying, skipping." >&2
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
        echo "Info: No content generated to copy." >&2
      fi
    else
      echo "Warning: xclip not found. Printing to stdout instead." >&2
      if [[ -n "$output" ]]; then echo "$output"; else echo "Info: No content generated to print." >&2; fi
    fi
  fi

  return 0
}

# --- Execution / Alias Definition ---

# Define the alias if the script is sourced (e.g., from .bashrc)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  alias cco="copy_code"
else
  # Allow direct execution (e.g., ./copy-code -g HEAD), calls the main function
  copy_code "$@"
fi
