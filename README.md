# Aardwolf Hammerforge Plugin

An automated weapon conversion plugin for Aardwolf that streamlines the process of converting weapons to hammers (hammerforge) and back to their original types (reforge).

## Overview

The Hammerforge plugin automatically processes your entire weapon inventory, converting weapons one at a time while handling different storage locations (inventory, wielded weapons, bags, keyrings). It provides real-time progress updates and comprehensive error handling.

## Requirements

**Important**: This plugin requires the updated Aardwolf Inventory (dinv) plugin with new search methods. You must use the fork found at:

**https://github.com/AardPlugins/aard-inventory**

The standard dinv plugin does not have the `SearchAndReturn` method required by this plugin.

## Installation

1. Install the updated dinv plugin from the link above
2. Download `Aardwolf_Forge.xml` and `Aardwolf_Forge.lua`
3. Place both files in your MUSHclient plugins directory
4. Load the plugin in MUSHclient

## Essential Commands

### Core Operations
- `hforge convert` - Convert all non-hammer weapons to hammers
- `hforge revert` - Convert all hammer weapons back to original types
- `hforge abort` - Stop current processing operation

### Status and Information
- `hforge status` - View all weapons with location, type, level, and damage type
- `hforge status hammer` - View only hammer weapons
- `hforge status nothammer` - View only non-hammer weapons
- `hforge help` - Display all available commands

### Maintenance
- `hforge update` - Update to the latest version
- `hforge reload` - Reload the plugin

## Important Notes

### Prerequisites
- **Must be at a forge** - Both hammerforge and reforge require you to be at a forge location
- **Level requirements** - Some weapons require minimum levels to forge/reforge
- **Metal weapons only** - Only metal-based weapons can be hammerforged

### Weapon Locations
The plugin automatically handles weapons stored in:
- **Inventory** - Ready for immediate processing
- **Wielded/Second** - Automatically removed and re-equipped after processing
- **Bags** - Retrieved from bags and stored back after processing
- **Keyrings** - Retrieved from keyring and stored back after processing

### Error Handling
- **Recoverable errors** (continues processing):
  - Weapon already correct type (hammer/non-hammer)
  - Non-metal weapons (hammerforge only)
  - Level requirements not met
- **Fatal errors** (aborts operation):
  - Not at a forge location
