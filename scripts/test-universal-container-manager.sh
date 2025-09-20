#!/bin/bash
# Test script for universal container manager

echo "Testing Universal Container Manager..."

# Test help command
echo "1. Testing help command..."
./scripts/universal-container-manager.sh help

echo ""
echo "2. Testing init command..."
./scripts/universal-container-manager.sh init

echo ""
echo "3. Testing status command..."
./scripts/universal-container-manager.sh status

echo "Basic tests completed!"