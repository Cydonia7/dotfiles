#!/bin/bash
#
# upload-to-remarkable.sh
# Upload PDFs and images to reMarkable device using RCU
#
# Description:
#   This script uploads files to a reMarkable device at 192.168.1.17.
#   - PDFs are uploaded directly
#   - Images are converted to PDF at 100 DPI for proper display
#   - Checks device connectivity before uploading
#   - Provides emoji-enhanced feedback
#
# Usage:
#   ./upload-to-remarkable.sh file1.pdf [name]
#   ./upload-to-remarkable.sh image.png "My Document"
#

# Constants
REMARKABLE_IP="192.168.1.17"
REMARKABLE_USER="root"
IMAGE_DENSITY=100
SSH_TIMEOUT=5
TEMP_DIR="/tmp/remarkable-uploads-$$"

# Counters for summary
UPLOADED_COUNT=0
FAILED_COUNT=0
CONVERTED_COUNT=0

#
# cleanup()
# Remove temporary directory and all contents
#
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        echo "🧹 Cleaning up..."
        rm -rf "$TEMP_DIR"
    fi
}

#
# check_dependencies()
# Verify required commands exist
#
check_dependencies() {
    local missing=0
    local deps=("rcu" "ssh" "file")

    # Check for ImageMagick (either magick or convert)
    if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
        echo "❌ Error: ImageMagick not found (need 'magick' or 'convert' command)"
        echo "   Install with: sudo pacman -S imagemagick"
        missing=1
    fi

    # Check other dependencies
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "❌ Error: '$cmd' command not found"
            if [ "$cmd" = "rcu" ]; then
                echo "   Install RCU from: https://github.com/Jayy001/RCU"
            fi
            missing=1
        fi
    done

    return $missing
}

#
# check_ssh_connectivity()
# Test network connectivity to reMarkable device using ping
#
check_ssh_connectivity() {
    ping -c 1 -W "$SSH_TIMEOUT" "$REMARKABLE_IP" &>/dev/null
    return $?
}

#
# wait_for_device()
# Loop until device is reachable
#
wait_for_device() {
    echo "⏳ Waiting for reMarkable device at $REMARKABLE_IP..."
    echo "   (Press Ctrl+C to cancel)"

    while true; do
        if check_ssh_connectivity; then
            echo "✅ Connected to reMarkable device"
            return 0
        fi
        sleep 5
    done
}

#
# detect_file_type()
# Determine if file is PDF, image, or unsupported
# Args: $1 - file path
# Returns: "pdf", "image", or "unsupported"
#
detect_file_type() {
    local filepath="$1"
    local mimetype

    mimetype=$(file --brief --mime-type "$filepath" 2>/dev/null)

    case "$mimetype" in
        application/pdf)
            echo "pdf"
            ;;
        image/*)
            echo "image"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

#
# convert_image_to_pdf()
# Convert image to PDF with proper density for A4 on reMarkable
# Args: $1 - input image path
#       $2 - optional output filename (without .pdf extension)
# Returns: output PDF path (or empty string on failure)
#
convert_image_to_pdf() {
    local input_image="$1"
    local output_name="$2"
    local basename_no_ext
    local output_pdf
    local magick_cmd

    # Use provided name or derive from input filename
    if [ -n "$output_name" ]; then
        basename_no_ext="$output_name"
    else
        basename_no_ext=$(basename "$input_image" | sed 's/\.[^.]*$//')
    fi

    output_pdf="$TEMP_DIR/${basename_no_ext}.pdf"

    echo "🔄 Converting $(basename "$input_image") to PDF..." >&2
    echo "   📁 Temp directory: $TEMP_DIR" >&2
    echo "   📄 Output will be: $output_pdf" >&2

    # Use 'magick' if available, otherwise fall back to 'convert'
    if command -v magick &> /dev/null; then
        magick_cmd="magick"
    else
        magick_cmd="convert"
    fi

    echo "   🔧 Using command: $magick_cmd" >&2

    # Convert with optimal settings for reMarkable
    # Note: -density must come AFTER the input image to set output resolution
    local error_output
    local exit_code

    error_output=$("$magick_cmd" "$input_image" \
        -density "$IMAGE_DENSITY" \
        "$output_pdf" 2>&1)
    exit_code=$?

    echo "   📊 Exit code: $exit_code" >&2

    if [ $exit_code -eq 0 ]; then
        # Verify output file exists and has content
        if [ -f "$output_pdf" ]; then
            if [ -s "$output_pdf" ]; then
                echo "✅ Conversion complete (size: $(du -h "$output_pdf" | cut -f1))" >&2
                echo "$output_pdf"
                return 0
            else
                echo "❌ Output file is empty" >&2
            fi
        else
            echo "❌ Output file not created" >&2
        fi
    fi

    echo "❌ Conversion failed" >&2
    if [ -n "$error_output" ]; then
        echo "   Error: $error_output" >&2
    fi
    return 1
}

#
# upload_file()
# Upload file to reMarkable using RCU
# Args: $1 - file path
# Returns: 0 on success, 1 on failure
#
upload_file() {
    local filepath="$1"
    local filename
    local filename_no_ext
    local output

    filename=$(basename "$filepath")
    # Remove .pdf extension for matching
    filename_no_ext="${filename%.pdf}"

    echo "⬆️  Uploading $filename..."
    echo "   📂 File path: $filepath" >&2

    # Capture RCU output to detect errors
    output=$(rcu --cli --autoconnect --upload-doc "$filepath" 2>&1)
    local exit_code=$?

    echo "   📊 RCU exit code: $exit_code" >&2
    if [ $exit_code -ne 0 ]; then
        echo "   ⚠️  RCU returned error, but checking if upload succeeded..." >&2
    fi

    # Wait a moment for the upload to be registered
    sleep 2

    # Verify upload by checking if document appears in list
    echo "   🔍 Verifying upload..." >&2
    if rcu --cli --autoconnect --list-documents 2>&1 | grep -F "$filename_no_ext" > /dev/null; then
        echo "✅ Upload successful: $filename"
        return 0
    else
        echo "❌ Upload failed: $filename"
        echo "   Document not found in reMarkable library" >&2
        if [ $exit_code -ne 0 ]; then
            echo "   RCU output:" >&2
            echo "$output" >&2
        fi

        # Check if it's a connection preset issue
        if echo "$output" | grep -iq "preset\|connection\|config"; then
            echo "   💡 Tip: Run 'rcu' once to configure connection preset"
        fi

        return 1
    fi
}

#
# show_usage()
# Display usage instructions
#
show_usage() {
    cat <<EOF
📚 reMarkable Upload Script

Usage:
  $(basename "$0") <file> [name]

Description:
  Upload a PDF or image to your reMarkable device at $REMARKABLE_IP

  📄 PDFs: Uploaded directly
  🖼️  Images: Automatically converted to PDF (100 DPI)

Arguments:
  file    - Path to PDF or image file
  name    - Optional name for the document (without .pdf extension)
            If not provided, uses the original filename

Supported formats:
  - PDF (.pdf)
  - Images (.png, .jpg, .jpeg, .gif, .bmp, .tiff, .webp)

Examples:
  $(basename "$0") document.pdf
  $(basename "$0") photo.png
  $(basename "$0") enigme4.png "Enigme 4"
  $(basename "$0") screenshot.png "My Notes"

Requirements:
  - RCU (reMarkable Connection Utility) installed and configured
  - SSH access to reMarkable device at $REMARKABLE_IP
  - ImageMagick for image conversion

Notes:
  - Run 'rcu' once to set up connection preset
  - Ensure SSH key authentication is configured for root@$REMARKABLE_IP

EOF
}

#
# main()
# Main script logic
#
main() {
    # Setup trap for cleanup
    trap cleanup EXIT INT TERM

    # Check if arguments provided
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi

    echo "🚀 Starting reMarkable upload process"
    echo ""

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    # Check device connectivity
    echo "🔍 Checking device connectivity..."
    if ! check_ssh_connectivity; then
        echo "❌ Device not reachable at $REMARKABLE_IP"
        wait_for_device || exit 1
    else
        echo "✅ Connected to reMarkable device"
    fi

    echo ""

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Parse arguments: file and optional name
    local filepath="$1"
    local output_name="${2:-}"

    # Check file exists
    if [ ! -f "$filepath" ]; then
        echo "❌ File not found: $filepath"
        exit 1
    fi

    # Check file is readable
    if [ ! -r "$filepath" ]; then
        echo "❌ File not readable: $filepath"
        exit 1
    fi

    # Detect file type
    filetype=$(detect_file_type "$filepath")

    case "$filetype" in
        pdf)
            echo "📄 PDF detected: $(basename "$filepath")"
            if upload_file "$filepath"; then
                ((UPLOADED_COUNT++))
            else
                ((FAILED_COUNT++))
            fi
            ;;
        image)
            echo "🖼️  Image detected: $(basename "$filepath")"
            converted_pdf=$(convert_image_to_pdf "$filepath" "$output_name")

            if [ -n "$converted_pdf" ] && [ -f "$converted_pdf" ]; then
                if upload_file "$converted_pdf"; then
                    ((UPLOADED_COUNT++))
                    ((CONVERTED_COUNT++))
                else
                    ((FAILED_COUNT++))
                fi
            else
                echo "❌ Failed to convert: $filepath"
                ((FAILED_COUNT++))
            fi
            ;;
        unsupported)
            echo "❓ Unsupported file type: $(basename "$filepath")"
            echo "❌ Skipping unsupported file"
            ((FAILED_COUNT++))
            ;;
    esac

    echo ""

    # Display summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Upload Summary:"
    echo "   ✅ Successful: $UPLOADED_COUNT file(s)"
    echo "   ❌ Failed: $FAILED_COUNT file(s)"
    echo "   🔄 Converted: $CONVERTED_COUNT image(s)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 Process complete!"
}

# Run main with all arguments
main "$@"
