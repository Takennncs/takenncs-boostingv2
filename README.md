# takenncs-boostingv2 - Boosting Script for QBCore

A comprehensive vehicle boosting script for QBCore FiveM servers. Players can accept boosting contracts, steal vehicles, and deliver them for rewards.

## 📋 Features

- Dynamic contract generation based on player level
- Multiple difficulty levels (Easy, Normal, Hard, Expert, Legendary)
- XP and leveling system
- Special and premium contracts
- Leaderboard system
- Admin commands for giving boosts
- Database persistence for player progress

## Item
```
	['takenncs_tablet'] = {
		label = 'Kahtlane Tahvel',
		weight = 0,
		description = 'Süsteemid ootavad?',
		client = {
			export = 'takenncs-boostingv2.openTablet',
		}
	},
```

## SQL

```
CREATE TABLE IF NOT EXISTS `takenncs_boosting` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `charId` varchar(50) NOT NULL,
    `xp` int(11) DEFAULT 0,
    `finished` int(11) DEFAULT 0,
    `failed` int(11) DEFAULT 0,
    `total_earned` int(11) DEFAULT 0,
    `premium_contracts` int(11) DEFAULT 0,
    `special_contracts` int(11) DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `charId` (`charId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `takenncs_boosting_active` (
    `id` varchar(50) NOT NULL,
    `charId` varchar(50) NOT NULL,
    `vehicle_model` varchar(50) NOT NULL,
    `vehicle_name` varchar(100) NOT NULL,
    `plate` varchar(10) NOT NULL,
    `price` int(11) NOT NULL,
    `difficulty` varchar(20) NOT NULL,
    `spawn_location` longtext NOT NULL,
    `delivery_location` longtext NOT NULL,
    `expires_at` datetime NOT NULL,
    PRIMARY KEY (`id`),
    KEY `charId` (`charId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Commands
- /boosting or /boost	Open boosting tablet
- /boostinghelp	Show boosting help menu
