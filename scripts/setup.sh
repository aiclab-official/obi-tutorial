#!/bin/bash
# Setup script for PULP OBI Tutorial
# This script clones the required PULP dependencies

set -e  # Exit on error

echo "PULP OBI Tutorial - Dependency Setup"
echo "====================================="

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed or not in PATH"
    exit 1
fi

# Create external directory if it doesn't exist
mkdir -p external
cd external

# Clone common_cells
if [ ! -d "common_cells" ]; then
    echo "Cloning common_cells..."
    git clone https://github.com/pulp-platform/common_cells.git
    echo "✓ common_cells cloned"
else
    echo "✓ common_cells already exists"
    cd common_cells
    echo "  Updating common_cells..."
    git pull origin master
    cd ..
fi

# Clone common_verification
if [ ! -d "common_verification" ]; then
    echo "Cloning common_verification..."
    git clone https://github.com/pulp-platform/common_verification.git
    echo "✓ common_verification cloned"
else
    echo "✓ common_verification already exists"
    cd common_verification
    echo "  Updating common_verification..."
    git pull origin master
    cd ..
fi

# Clone obi
if [ ! -d "obi" ]; then
    echo "Cloning obi..."
    git clone https://github.com/pulp-platform/obi.git
    echo "✓ obi cloned"
else
    echo "✓ obi already exists"
    cd obi
    echo "  Updating obi..."
    git pull origin master
    cd ..
fi

cd ..  # Return to project root

echo ""
echo "Setup completed successfully!"
echo ""
echo "Dependencies installed in external/:"
echo "  - common_cells/"
echo "  - common_verification/"
echo "  - obi/"
echo ""
echo "You can now run simulations:"
echo "  make test_custom       # Test custom modules only"
echo "  make test_master       # Test custom master vs PULP memory"
echo "  make test_slave        # Test custom slave vs PULP master"
echo "  make all               # Run all tests"
