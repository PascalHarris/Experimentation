#!/bin/zsh
#===============================================================================
# Terminal Graphics Library (zsh version)
#===============================================================================
# A zsh library for drawing graphics in the terminal using Unicode half-block
# characters. Each character cell represents 2 pixels (1 wide x 2 tall).
#
# Coordinate system:
#   - Origin (0,0) is at the BOTTOM-LEFT of the terminal
#   - X increases rightward
#   - Y increases upward
#   - Each X unit = 1 character column
#   - Each Y unit = 1 half-block (half a character row)
#
# Dependencies: zsh, tput
#===============================================================================

#-------------------------------------------------------------------------------
# Colour Definitions
#-------------------------------------------------------------------------------
# ANSI colour codes for foreground and background
# Usage: Use colour names directly with drawing functions

typeset -A FG_COLOURS
FG_COLOURS=(
    black 30      red 31        green 32      yellow 33
    blue 34       magenta 35    cyan 36       white 37
    bright_black 90    bright_red 91      bright_green 92
    bright_yellow 93   bright_blue 94     bright_magenta 95
    bright_cyan 96     bright_white 97
)

typeset -A BG_COLOURS
BG_COLOURS=(
    black 40      red 41        green 42      yellow 43
    blue 44       magenta 45    cyan 46       white 47
    bright_black 100   bright_red 101     bright_green 102
    bright_yellow 103  bright_blue 104    bright_magenta 105
    bright_cyan 106    bright_white 107
)

# Special value for transparent/no colour
typeset -r TRANSPARENT="none"

#-------------------------------------------------------------------------------
# Unicode Block Characters
#-------------------------------------------------------------------------------
# ▀ Upper half block (U+2580) - top pixel filled
# ▄ Lower half block (U+2584) - bottom pixel filled
# █ Full block (U+2588) - both pixels filled
#   Space - neither pixel filled

typeset -r UPPER_HALF=$'\u2580'
typeset -r LOWER_HALF=$'\u2584'
typeset -r FULL_BLOCK=$'\u2588'

#-------------------------------------------------------------------------------
# Global Variables
#-------------------------------------------------------------------------------
# Terminal dimensions in pixel units
TERM_WIDTH=0      # Width in pixels (= columns)
TERM_HEIGHT=0     # Height in pixels (= rows * 2)

# Internal framebuffer: stores colour name for each pixel
# Indexed as FRAMEBUFFER[y * TERM_WIDTH + x + 1] (zsh arrays are 1-indexed)
typeset -ga FRAMEBUFFER=()

#-------------------------------------------------------------------------------
# GetTerminalSize
#-------------------------------------------------------------------------------
# Calculates the terminal dimensions in pixel units.
#
# Sets global variables:
#   TERM_WIDTH  - Width in pixels (equals terminal columns)
#   TERM_HEIGHT - Height in pixels (equals terminal rows * 2)
#
# Returns: 0 on success, 1 on failure
#-------------------------------------------------------------------------------
GetTerminalSize() {
    # Get terminal dimensions - read directly into variables to avoid subshell issues
    TERM_WIDTH="${COLUMNS:-$(tput cols)}"
    TERM_HEIGHT="${LINES:-$(tput lines)}"
    
    # If still not set, try tput with explicit terminal
    if [[ "$TERM_WIDTH" == "80" && "$TERM_HEIGHT" == "24" ]]; then
        # Force tput to query the terminal directly
        TERM_WIDTH=$(stty size 2>/dev/null | cut -d' ' -f2)
        TERM_HEIGHT=$(stty size 2>/dev/null | cut -d' ' -f1)
    fi
    
    # Validate we got numeric values
    if ! [[ "$TERM_WIDTH" =~ ^[0-9]+$ && "$TERM_HEIGHT" =~ ^[0-9]+$ ]]; then
        echo "Error: Could not determine terminal size" >&2
        return 1
    fi
    
    # Double height for half-block pixels
    TERM_HEIGHT=$((TERM_HEIGHT * 2))
    
    return 0
}

#-------------------------------------------------------------------------------
# InitFramebuffer
#-------------------------------------------------------------------------------
# Initialises the framebuffer with a background colour.
#
# Parameters:
#   $1 - Background colour name (optional, defaults to "black")
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
InitFramebuffer() {
    local bg_colour="${1:-black}"
    local total_pixels=$((TERM_WIDTH * TERM_HEIGHT))
    
    FRAMEBUFFER=()
    for ((i = 1; i <= total_pixels; i++)); do
        FRAMEBUFFER[i]="$bg_colour"
    done
    
    return 0
}

#-------------------------------------------------------------------------------
# PlotPoint
#-------------------------------------------------------------------------------
# Plots a single pixel at the specified coordinates.
#
# Parameters:
#   $1 - X coordinate (0 = left edge)
#   $2 - Y coordinate (0 = bottom edge)
#   $3 - Colour name (e.g., "red", "bright_blue")
#
# Coordinate system:
#   - (0,0) is at the bottom-left corner
#   - X increases to the right
#   - Y increases upward
#
# Returns:
#   0 - Point plotted successfully
#   1 - Point was outside terminal bounds (nothing plotted)
#-------------------------------------------------------------------------------
PlotPoint() {
    local x=$1
    local y=$2
    local colour=$3
    
    # Bounds checking - silently ignore out-of-bounds points
    if ((x < 0 || x >= TERM_WIDTH || y < 0 || y >= TERM_HEIGHT)); then
        return 1
    fi
    
    # Store in framebuffer (zsh arrays are 1-indexed)
    local index=$((y * TERM_WIDTH + x + 1))
    FRAMEBUFFER[index]="$colour"
    
    return 0
}

#-------------------------------------------------------------------------------
# RenderFramebuffer
#-------------------------------------------------------------------------------
# Renders the framebuffer to the terminal.
#
# This function processes the framebuffer two Y-rows at a time (one character
# row) and outputs the appropriate half-block characters with colours.
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
RenderFramebuffer() {
    local row col
    local top_colour bottom_colour
    local top_idx bottom_idx
    local output=""
    
    # Hide cursor during rendering
    tput civis
    
    # Move to top-left
    tput cup 0 0
    
    # Process from top of screen to bottom
    # Terminal row 0 corresponds to the highest Y values
    local term_rows=$((TERM_HEIGHT / 2))
    
    for ((row = term_rows - 1; row >= 0; row--)); do
        local line=""
        local last_fg="" last_bg=""
        
        for ((col = 0; col < TERM_WIDTH; col++)); do
            # Top pixel (higher Y value) and bottom pixel (lower Y value)
            # +1 for zsh 1-indexed arrays
            top_idx=$(((row * 2 + 1) * TERM_WIDTH + col + 1))
            bottom_idx=$((row * 2 * TERM_WIDTH + col + 1))
            
            top_colour="${FRAMEBUFFER[top_idx]}"
            bottom_colour="${FRAMEBUFFER[bottom_idx]}"
            
            # Determine character and colours to use
            if [[ "$top_colour" == "$bottom_colour" ]]; then
                # Both pixels same colour - use full block with that colour
                local fg_code="${FG_COLOURS[$top_colour]:-37}"
                if [[ "$last_fg" != "$fg_code" ]]; then
                    line+="\033[${fg_code}m"
                    last_fg="$fg_code"
                fi
                line+="$FULL_BLOCK"
            else
                # Different colours - use upper half block
                # Foreground = top colour, Background = bottom colour
                local fg_code="${FG_COLOURS[$top_colour]:-37}"
                local bg_code="${BG_COLOURS[$bottom_colour]:-40}"
                
                if [[ "$last_fg" != "$fg_code" || "$last_bg" != "$bg_code" ]]; then
                    line+="\033[${fg_code};${bg_code}m"
                    last_fg="$fg_code"
                    last_bg="$bg_code"
                fi
                line+="$UPPER_HALF"
            fi
        done
        
        # Reset colours at end of line and add newline (except for last row)
        line+="\033[0m"
        output+="$line"
        if ((row > 0)); then
            output+=$'\n'
        fi
    done
    
    # Output everything at once for speed
    print -n "$output"
    
    # Show cursor again
    tput cnorm
    
    return 0
}

#-------------------------------------------------------------------------------
# ClearScreen
#-------------------------------------------------------------------------------
# Clears the terminal and resets the framebuffer.
#
# Parameters:
#   $1 - Background colour (optional, defaults to "black")
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
ClearScreen() {
    local bg_colour="${1:-black}"
    
    clear
    InitFramebuffer "$bg_colour"
    
    return 0
}

#-------------------------------------------------------------------------------
# DrawLine
#-------------------------------------------------------------------------------
# Draws a line between two points using Bresenham's algorithm.
#
# Parameters:
#   $1 - X1 (start X coordinate)
#   $2 - Y1 (start Y coordinate)
#   $3 - X2 (end X coordinate)
#   $4 - Y2 (end Y coordinate)
#   $5 - Colour name
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
DrawLine() {
    local x1=$1 y1=$2 x2=$3 y2=$4 colour=$5
    local dx dy sx sy err e2
    
    # Calculate deltas
    if ((x2 > x1)); then dx=$((x2 - x1)); sx=1; else dx=$((x1 - x2)); sx=-1; fi
    if ((y2 > y1)); then dy=$((y2 - y1)); sy=1; else dy=$((y1 - y2)); sy=-1; fi
    
    # Bresenham's algorithm
    if ((dx > dy)); then
        err=$((dx / 2))
        while ((x1 != x2)); do
            PlotPoint "$x1" "$y1" "$colour"
            err=$((err - dy))
            if ((err < 0)); then
                y1=$((y1 + sy))
                err=$((err + dx))
            fi
            x1=$((x1 + sx))
        done
    else
        err=$((dy / 2))
        while ((y1 != y2)); do
            PlotPoint "$x1" "$y1" "$colour"
            err=$((err - dx))
            if ((err < 0)); then
                x1=$((x1 + sx))
                err=$((err + dy))
            fi
            y1=$((y1 + sy))
        done
    fi
    PlotPoint "$x2" "$y2" "$colour"
    
    return 0
}

#-------------------------------------------------------------------------------
# isqrt - Integer square root helper
#-------------------------------------------------------------------------------
# Calculates integer square root using Newton's method.
# Avoids dependency on bc or floating point.
#
# Parameters:
#   $1 - Number to find square root of
#
# Outputs: Integer square root to stdout
#-------------------------------------------------------------------------------
isqrt() {
    local n=$1
    if ((n < 0)); then echo 0; return; fi
    if ((n < 2)); then echo $n; return; fi
    
    local x=$n
    local y=$(( (x + 1) / 2 ))
    
    while ((y < x)); do
        x=$y
        y=$(( (x + n / x) / 2 ))
    done
    
    echo $x
}

#-------------------------------------------------------------------------------
# DrawCircle
#-------------------------------------------------------------------------------
# Draws a circle (outline and optional fill) centred at the specified position.
#
# Parameters:
#   $1 - Centre X coordinate
#   $2 - Centre Y coordinate
#   $3 - Width (horizontal diameter in pixels)
#   $4 - Height (vertical diameter in pixels)
#   $5 - Line colour (outline colour, use "none" for no outline)
#   $6 - Fill colour (interior colour, use "none" for no fill)
#
# Notes:
#   - Uses midpoint ellipse algorithm for drawing
#   - If width != height, draws an ellipse
#   - Fill is drawn first, then outline (so outline is always visible)
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
DrawCircle() {
    local cx=$1 cy=$2 width=$3 height=$4 line_colour=$5 fill_colour=$6
    
    # Calculate radii (half of width/height)
    local rx=$((width / 2))
    local ry=$((height / 2))
    
    # Handle degenerate cases
    if ((rx <= 0 || ry <= 0)); then
        if [[ "$line_colour" != "$TRANSPARENT" && "$line_colour" != "none" ]]; then
            PlotPoint "$cx" "$cy" "$line_colour"
        fi
        return 0
    fi
    
    # Draw fill first if specified
    if [[ "$fill_colour" != "$TRANSPARENT" && "$fill_colour" != "none" ]]; then
        # Scan line fill for ellipse
        local y x_bound
        for ((y = -ry; y <= ry; y++)); do
            # Calculate x bounds for this y using ellipse equation
            local y_sq=$((y * y))
            local ry_sq=$((ry * ry))
            local rx_sq=$((rx * rx))
            
            local inner=$((rx_sq * (ry_sq - y_sq)))
            if ((inner < 0)); then inner=0; fi
            
            # Integer square root
            x_bound=$(( $(isqrt $inner) / ry ))
            
            # Draw horizontal line at this y
            local draw_y=$((cy + y))
            local x
            for ((x = -x_bound; x <= x_bound; x++)); do
                PlotPoint "$((cx + x))" "$draw_y" "$fill_colour"
            done
        done
    fi
    
    # Draw outline if specified
    if [[ "$line_colour" != "$TRANSPARENT" && "$line_colour" != "none" ]]; then
        # Midpoint ellipse algorithm
        local x=0
        local y=$ry
        local rx_sq=$((rx * rx))
        local ry_sq=$((ry * ry))
        local two_rx_sq=$((2 * rx_sq))
        local two_ry_sq=$((2 * ry_sq))
        local px=0
        local py=$((two_rx_sq * y))
        
        # Plot initial points in all four quadrants
        PlotPoint "$((cx + x))" "$((cy + y))" "$line_colour"
        PlotPoint "$((cx - x))" "$((cy + y))" "$line_colour"
        PlotPoint "$((cx + x))" "$((cy - y))" "$line_colour"
        PlotPoint "$((cx - x))" "$((cy - y))" "$line_colour"
        
        # Region 1: dy/dx < 1
        local p=$((ry_sq - rx_sq * ry + rx_sq / 4))
        while ((px < py)); do
            ((x++))
            ((px += two_ry_sq))
            if ((p < 0)); then
                ((p += ry_sq + px))
            else
                ((y--))
                ((py -= two_rx_sq))
                ((p += ry_sq + px - py))
            fi
            PlotPoint "$((cx + x))" "$((cy + y))" "$line_colour"
            PlotPoint "$((cx - x))" "$((cy + y))" "$line_colour"
            PlotPoint "$((cx + x))" "$((cy - y))" "$line_colour"
            PlotPoint "$((cx - x))" "$((cy - y))" "$line_colour"
        done
        
        # Region 2: dy/dx >= 1
        p=$((ry_sq * (x * x + x) + rx_sq * (y - 1) * (y - 1) - rx_sq * ry_sq))
        while ((y > 0)); do
            ((y--))
            ((py -= two_rx_sq))
            if ((p > 0)); then
                ((p += rx_sq - py))
            else
                ((x++))
                ((px += two_ry_sq))
                ((p += rx_sq - py + px))
            fi
            PlotPoint "$((cx + x))" "$((cy + y))" "$line_colour"
            PlotPoint "$((cx - x))" "$((cy + y))" "$line_colour"
            PlotPoint "$((cx + x))" "$((cy - y))" "$line_colour"
            PlotPoint "$((cx - x))" "$((cy - y))" "$line_colour"
        done
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# DrawSquare
#-------------------------------------------------------------------------------
# Draws a rectangle (outline and optional fill) centred at the specified position.
#
# Parameters:
#   $1 - Centre X coordinate
#   $2 - Centre Y coordinate
#   $3 - Width (in pixels)
#   $4 - Height (in pixels)
#   $5 - Line colour (outline colour, use "none" for no outline)
#   $6 - Fill colour (interior colour, use "none" for no fill)
#
# Notes:
#   - Despite the name, can draw any rectangle (not just squares)
#   - Fill is drawn first, then outline
#   - Outline is 1 pixel thick
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
DrawSquare() {
    local cx=$1 cy=$2 width=$3 height=$4 line_colour=$5 fill_colour=$6
    
    # Calculate bounds
    local half_w=$((width / 2))
    local half_h=$((height / 2))
    local left=$((cx - half_w))
    local right=$((cx + half_w))
    local bottom=$((cy - half_h))
    local top=$((cy + half_h))
    
    # Adjust for even dimensions to keep centering consistent
    if ((width % 2 == 0)); then ((right--)); fi
    if ((height % 2 == 0)); then ((top--)); fi
    
    # Draw fill first if specified
    if [[ "$fill_colour" != "$TRANSPARENT" && "$fill_colour" != "none" ]]; then
        local x y
        for ((y = bottom; y <= top; y++)); do
            for ((x = left; x <= right; x++)); do
                PlotPoint "$x" "$y" "$fill_colour"
            done
        done
    fi
    
    # Draw outline if specified
    if [[ "$line_colour" != "$TRANSPARENT" && "$line_colour" != "none" ]]; then
        local i
        # Top and bottom edges
        for ((i = left; i <= right; i++)); do
            PlotPoint "$i" "$top" "$line_colour"
            PlotPoint "$i" "$bottom" "$line_colour"
        done
        # Left and right edges
        for ((i = bottom; i <= top; i++)); do
            PlotPoint "$left" "$i" "$line_colour"
            PlotPoint "$right" "$i" "$line_colour"
        done
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# Colour Palette for Fractals
#-------------------------------------------------------------------------------
# Array of colour names for fractal colouring based on iteration count
# Ordered from "inside" colours to "outside" colours

typeset -ga FRACTAL_PALETTE=(
    "black"
    "blue"
    "bright_blue"
    "cyan"
    "bright_cyan"
    "green"
    "bright_green"
    "yellow"
    "bright_yellow"
    "red"
    "bright_red"
    "magenta"
    "bright_magenta"
    "white"
    "bright_white"
)

#-------------------------------------------------------------------------------
# GetColourForIteration
#-------------------------------------------------------------------------------
# Returns a colour name based on iteration count for fractal colouring.
#
# Parameters:
#   $1 - Iteration count when point escaped
#   $2 - Maximum iterations (points that didn't escape)
#
# Outputs: Colour name to stdout
#-------------------------------------------------------------------------------
GetColourForIteration() {
    local iter=$1
    local max_iter=$2
    
    # Points that never escaped are black (inside the set)
    if ((iter >= max_iter)); then
        echo "black"
        return
    fi
    
    # Map iteration to palette index
    local palette_size=${#FRACTAL_PALETTE[@]}
    local index=$(( (iter % (palette_size - 1)) + 1 ))
    
    echo "${FRACTAL_PALETTE[index]}"
}

#-------------------------------------------------------------------------------
# DrawMandelbrot
#-------------------------------------------------------------------------------
# Renders the Mandelbrot set fractal to the framebuffer.
#
# The Mandelbrot set is defined as the set of complex numbers c for which
# the iteration z(n+1) = z(n)² + c does not diverge when starting with z(0) = 0.
#
# Parameters (all optional, with defaults):
#   $1 - Centre X in complex plane (default: -0.5)
#   $2 - Centre Y in complex plane (default: 0.0)
#   $3 - Zoom level / scale (default: 1.0, higher = more zoomed in)
#   $4 - Maximum iterations (default: 50)
#
# Default view shows the classic Mandelbrot set view with the main cardioid
# and the characteristic "snowman" shape visible.
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
DrawMandelbrot() {
    local -F center_re=${1:--0.5}
    local -F center_im=${2:-0.0}
    local -F zoom=${3:-1.0}
    local max_iter=${4:-50}
    
    # Calculate the view bounds
    # Base range is approximately -2.5 to 1.0 on real axis, -1.5 to 1.5 on imaginary
    # Adjust for aspect ratio (terminal characters are ~2x tall as wide)
    local -F base_range=3.0
    local -F range=$(( base_range / zoom ))
    
    # Aspect ratio correction (each pixel is 1 char wide, 0.5 char tall)
    local -F aspect=$(( TERM_WIDTH * 1.0 / TERM_HEIGHT ))
    
    local -F re_min=$(( center_re - range * aspect / 2.0 ))
    local -F re_max=$(( center_re + range * aspect / 2.0 ))
    local -F im_min=$(( center_im - range / 2.0 ))
    local -F im_max=$(( center_im + range / 2.0 ))
    
    # Calculate step sizes
    local -F re_step=$(( (re_max - re_min) / TERM_WIDTH ))
    local -F im_step=$(( (im_max - im_min) / TERM_HEIGHT ))
    
    # Iterate over each pixel
    local px py
    local -F c_re c_im
    local -F z_re z_im z_re_new
    local iter
    local colour
    local palette_size=${#FRACTAL_PALETTE[@]}
    local last_percent=-1
    
    for ((py = 0; py < TERM_HEIGHT; py++)); do
        # Show progress
        local percent=$(( (py * 100) / TERM_HEIGHT ))
        if ((percent != last_percent)); then
            printf "\rRendering Mandelbrot: %3d%%" "$percent"
            last_percent=$percent
        fi
        
        for ((px = 0; px < TERM_WIDTH; px++)); do
            # Map pixel to complex plane
            c_re=$(( re_min + px * re_step ))
            c_im=$(( im_min + py * im_step ))
            
            # Iterate z = z² + c
            z_re=0.0
            z_im=0.0
            iter=0
            
            while ((iter < max_iter)); do
                # Check if escaped (|z| > 2)
                if (( z_re * z_re + z_im * z_im > 4.0 )); then
                    break
                fi
                
                # z = z² + c
                z_re_new=$(( z_re * z_re - z_im * z_im + c_re ))
                z_im=$(( 2.0 * z_re * z_im + c_im ))
                z_re=$z_re_new
                
                ((iter++))
            done
            
            # Inline colour lookup (avoids subshell overhead)
            if ((iter >= max_iter)); then
                colour="black"
            else
                local index=$(( (iter % (palette_size - 1)) + 1 ))
                colour="${FRACTAL_PALETTE[index]}"
            fi
            PlotPoint $px $py "$colour"
        done
    done
    printf "\rRendering Mandelbrot: 100%%\n"
    
    return 0
}

#-------------------------------------------------------------------------------
# DrawJulia
#-------------------------------------------------------------------------------
# Renders a Julia set fractal to the framebuffer.
#
# Julia sets are related to the Mandelbrot set. For a fixed complex number c,
# the Julia set is the set of complex numbers z for which the iteration
# z(n+1) = z(n)² + c does not diverge.
#
# Parameters (all optional, with defaults):
#   $1 - Real part of c constant (default: -0.7)
#   $2 - Imaginary part of c constant (default: 0.27015)
#   $3 - Centre X in complex plane (default: 0.0)
#   $4 - Centre Y in complex plane (default: 0.0)
#   $5 - Zoom level / scale (default: 1.0, higher = more zoomed in)
#   $6 - Maximum iterations (default: 50)
#
# Popular c values for interesting Julia sets:
#   -0.7, 0.27015    - Classic "dendrite" pattern (default)
#   -0.8, 0.156      - Spiral pattern
#   -0.4, 0.6        - Rabbit-like pattern
#   0.285, 0.01      - Siegel disk
#   -0.835, -0.2321  - Douady's rabbit
#   -0.7269, 0.1889  - Electric fractal
#
# Returns: 0 on success
#-------------------------------------------------------------------------------
DrawJulia() {
    local -F c_re=${1:--0.7}
    local -F c_im=${2:-0.27015}
    local -F center_re=${3:-0.0}
    local -F center_im=${4:-0.0}
    local -F zoom=${5:-1.0}
    local max_iter=${6:-50}
    
    # Calculate the view bounds
    # Julia sets are typically viewed in range -2 to 2
    local -F base_range=4.0
    local -F range=$(( base_range / zoom ))
    
    # Aspect ratio correction
    local -F aspect=$(( TERM_WIDTH * 1.0 / TERM_HEIGHT ))
    
    local -F re_min=$(( center_re - range * aspect / 2.0 ))
    local -F re_max=$(( center_re + range * aspect / 2.0 ))
    local -F im_min=$(( center_im - range / 2.0 ))
    local -F im_max=$(( center_im + range / 2.0 ))
    
    # Calculate step sizes
    local -F re_step=$(( (re_max - re_min) / TERM_WIDTH ))
    local -F im_step=$(( (im_max - im_min) / TERM_HEIGHT ))
    
    # Iterate over each pixel
    local px py
    local -F z_re z_im z_re_new
    local iter
    local colour
    local palette_size=${#FRACTAL_PALETTE[@]}
    local last_percent=-1
    
    for ((py = 0; py < TERM_HEIGHT; py++)); do
        # Show progress
        local percent=$(( (py * 100) / TERM_HEIGHT ))
        if ((percent != last_percent)); then
            printf "\rRendering Julia: %3d%%" "$percent"
            last_percent=$percent
        fi
        
        for ((px = 0; px < TERM_WIDTH; px++)); do
            # Map pixel to complex plane - this is the starting z value
            z_re=$(( re_min + px * re_step ))
            z_im=$(( im_min + py * im_step ))
            
            iter=0
            
            while ((iter < max_iter)); do
                # Check if escaped (|z| > 2)
                if (( z_re * z_re + z_im * z_im > 4.0 )); then
                    break
                fi
                
                # z = z² + c (c is constant for Julia sets)
                z_re_new=$(( z_re * z_re - z_im * z_im + c_re ))
                z_im=$(( 2.0 * z_re * z_im + c_im ))
                z_re=$z_re_new
                
                ((iter++))
            done
            
            # Inline colour lookup (avoids subshell overhead)
            if ((iter >= max_iter)); then
                colour="black"
            else
                local index=$(( (iter % (palette_size - 1)) + 1 ))
                colour="${FRACTAL_PALETTE[index]}"
            fi
            PlotPoint $px $py "$colour"
        done
    done
    printf "\rRendering Julia: 100%%\n"
    
    return 0
}

#-------------------------------------------------------------------------------
# ShowProgress
#-------------------------------------------------------------------------------
# Displays a simple progress indicator during fractal rendering.
#
# Parameters:
#   $1 - Current progress (0-100)
#   $2 - Message to display
#-------------------------------------------------------------------------------
ShowProgress() {
    local progress=$1
    local message=$2
    printf "\r%s: %3d%%" "$message" "$progress"
}

#-------------------------------------------------------------------------------
# RenderFractalWithProgress
#-------------------------------------------------------------------------------
# Wrapper that shows progress while rendering fractals.
#
# Parameters:
#   $1 - Fractal type ("mandelbrot" or "julia")
#   $@ - Remaining parameters passed to fractal function
#-------------------------------------------------------------------------------
RenderFractalWithProgress() {
    local fractal_type=$1
    shift
    
    echo "Rendering ${fractal_type} fractal..."
    echo "Terminal: ${TERM_WIDTH}x${TERM_HEIGHT} pixels"
    echo ""
    
    case "$fractal_type" in
        mandelbrot)
            DrawMandelbrot "$@"
            ;;
        julia)
            DrawJulia "$@"
            ;;
    esac
    
    echo ""
}

#-------------------------------------------------------------------------------
# PromptFloat
#-------------------------------------------------------------------------------
# Prompts user for a floating-point value with a default.
#
# Parameters:
#   $1 - Prompt message
#   $2 - Default value
#
# Outputs: Entered value (or default) to stdout
#-------------------------------------------------------------------------------
PromptFloat() {
    local prompt=$1
    local default=$2
    local value
    
    printf "%s [%s]: " "$prompt" "$default" >&2
    read -r value
    
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

#-------------------------------------------------------------------------------
# PromptInt
#-------------------------------------------------------------------------------
# Prompts user for an integer value with a default.
#
# Parameters:
#   $1 - Prompt message
#   $2 - Default value
#
# Outputs: Entered value (or default) to stdout
#-------------------------------------------------------------------------------
PromptInt() {
    local prompt=$1
    local default=$2
    local value
    
    printf "%s [%s]: " "$prompt" "$default" >&2
    read -r value
    
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

#-------------------------------------------------------------------------------
# ShowMandelbrotMenu
#-------------------------------------------------------------------------------
# Displays options for Mandelbrot rendering and renders the fractal.
#-------------------------------------------------------------------------------
ShowMandelbrotMenu() {
    echo ""
    echo "=== Mandelbrot Set ==="
    echo ""
    echo "Default settings show the classic Mandelbrot view."
    echo "Press Enter to accept defaults, or enter custom values."
    echo ""
    
    local center_re=$(PromptFloat "Centre X (real)" "-0.5")
    local center_im=$(PromptFloat "Centre Y (imaginary)" "0.0")
    local zoom=$(PromptFloat "Zoom level" "1.0")
    local max_iter=$(PromptInt "Max iterations" "50")
    
    echo ""
    echo "Rendering... (this may take a moment)"
    
    # Re-query terminal size in case window was resized
    GetTerminalSize
    
    echo "DEBUG: Detected terminal: ${TERM_WIDTH}x${TERM_HEIGHT} pixels"
    echo "DEBUG: tput cols=$(tput cols) tput lines=$(tput lines)"
    echo "Press Enter to continue..."
    read -r
    
    ClearScreen "black"
    DrawMandelbrot "$center_re" "$center_im" "$zoom" "$max_iter"
    RenderFramebuffer
    
    # Position cursor at bottom of screen for message
    tput cup "$((TERM_HEIGHT / 2))" 0
    echo "Mandelbrot set rendered. Press Enter to return to menu..."
    read -r
}

#-------------------------------------------------------------------------------
# ShowJuliaMenu
#-------------------------------------------------------------------------------
# Displays options for Julia set rendering and renders the fractal.
#-------------------------------------------------------------------------------
ShowJuliaMenu() {
    echo ""
    echo "=== Julia Set ==="
    echo ""
    echo "Popular c values for interesting patterns:"
    echo "  1) Classic dendrite:  c = -0.7 + 0.27015i (default)"
    echo "  2) Spiral:            c = -0.8 + 0.156i"
    echo "  3) Rabbit:            c = -0.4 + 0.6i"
    echo "  4) Siegel disk:       c = 0.285 + 0.01i"
    echo "  5) Douady's rabbit:   c = -0.835 - 0.2321i"
    echo "  6) Electric:          c = -0.7269 + 0.1889i"
    echo "  7) Custom values"
    echo ""
    
    local preset
    printf "Choose preset (1-7) [1]: "
    read -r preset
    preset=${preset:-1}
    
    local c_re c_im
    case "$preset" in
        1) c_re="-0.7";    c_im="0.27015" ;;
        2) c_re="-0.8";    c_im="0.156" ;;
        3) c_re="-0.4";    c_im="0.6" ;;
        4) c_re="0.285";   c_im="0.01" ;;
        5) c_re="-0.835";  c_im="-0.2321" ;;
        6) c_re="-0.7269"; c_im="0.1889" ;;
        7)
            c_re=$(PromptFloat "c real part" "-0.7")
            c_im=$(PromptFloat "c imaginary part" "0.27015")
            ;;
        *)
            c_re="-0.7"
            c_im="0.27015"
            ;;
    esac
    
    echo ""
    echo "View settings (press Enter for defaults):"
    local center_re=$(PromptFloat "Centre X" "0.0")
    local center_im=$(PromptFloat "Centre Y" "0.0")
    local zoom=$(PromptFloat "Zoom level" "1.0")
    local max_iter=$(PromptInt "Max iterations" "50")
    
    echo ""
    echo "Rendering... (this may take a moment)"
    
    # Re-query terminal size in case window was resized
    GetTerminalSize
    
    ClearScreen "black"
    DrawJulia "$c_re" "$c_im" "$center_re" "$center_im" "$zoom" "$max_iter"
    RenderFramebuffer
    
    # Position cursor at bottom of screen for message
    tput cup "$((TERM_HEIGHT / 2))" 0
    echo "Julia set (c = ${c_re} + ${c_im}i) rendered. Press Enter to return to menu..."
    read -r
}

#-------------------------------------------------------------------------------
# ShowShapesDemo
#-------------------------------------------------------------------------------
# Demonstrates the basic shape drawing capabilities.
#-------------------------------------------------------------------------------
ShowShapesDemo() {
    # Re-query terminal size in case window was resized
    GetTerminalSize
    
    ClearScreen "black"
    
    local cx=$((TERM_WIDTH / 2))
    local cy=$((TERM_HEIGHT / 2))
    
    # Draw a large yellow circle with red outline
    DrawCircle "$cx" "$cy" 40 30 "red" "yellow"
    
    # Draw a smaller blue square offset to the left
    DrawSquare "$((cx - 30))" "$cy" 20 20 "bright_white" "blue"
    
    # Draw a smaller green square offset to the right
    DrawSquare "$((cx + 30))" "$cy" 20 20 "bright_white" "green"
    
    # Draw an unfilled magenta circle at the top
    DrawCircle "$cx" "$((cy + 25))" 15 15 "magenta" "none"
    
    # Draw some individual points in a pattern at the bottom
    local i
    for ((i = 0; i < 20; i++)); do
        PlotPoint "$((cx - 10 + i))" "$((cy - 25))" "cyan"
        PlotPoint "$((cx - 10 + i))" "$((cy - 27))" "bright_cyan"
    done
    
    # Draw lines forming a triangle
    local tri_cx=$((cx))
    local tri_cy=$((cy - 35))
    DrawLine "$tri_cx" "$((tri_cy + 8))" "$((tri_cx - 10))" "$((tri_cy - 5))" "bright_yellow"
    DrawLine "$((tri_cx - 10))" "$((tri_cy - 5))" "$((tri_cx + 10))" "$((tri_cy - 5))" "bright_yellow"
    DrawLine "$((tri_cx + 10))" "$((tri_cy - 5))" "$tri_cx" "$((tri_cy + 8))" "bright_yellow"
    
    RenderFramebuffer
    
    tput cup "$((TERM_HEIGHT / 2))" 0
    echo "Shapes demo complete. Press Enter to return to menu..."
    read -r
}

#-------------------------------------------------------------------------------
# MainMenu
#-------------------------------------------------------------------------------
# Displays the main menu and handles user selection.
#-------------------------------------------------------------------------------
MainMenu() {
    GetTerminalSize
    
    while true; do
        clear
        echo "╔════════════════════════════════════════════╗"
        echo "║     Terminal Graphics - Fractal Viewer     ║"
        echo "╠════════════════════════════════════════════╣"
        echo "║                                            ║"
        echo "║  1) Mandelbrot Set                         ║"
        echo "║  2) Julia Set                              ║"
        echo "║  3) Shapes Demo                            ║"
        echo "║  4) Quit                                   ║"
        echo "║                                            ║"
        echo "╚════════════════════════════════════════════╝"
        echo ""
        echo "Terminal: ${TERM_WIDTH}x${TERM_HEIGHT} pixels"
        echo ""
        printf "Select option (1-4): "
        
        local choice
        read -r choice
        
        case "$choice" in
            1)
                ShowMandelbrotMenu
                ;;
            2)
                ShowJuliaMenu
                ;;
            3)
                ShowShapesDemo
                ;;
            4|q|Q)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option. Press Enter to continue..."
                read -r
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Main - Run menu if script is executed directly
#-------------------------------------------------------------------------------
if [[ "${ZSH_EVAL_CONTEXT}" == "toplevel" ]]; then
    MainMenu
fi
