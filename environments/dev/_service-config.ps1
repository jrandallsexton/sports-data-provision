# Shared configuration for SportDeets services
# This file contains the service names and their corresponding image names

# Define services hashtable (serviceName -> imageName)
$services = @{
    "api-public-dev" = "sportsdataapi"
    "contest-football-ncaa-dev" = "sportsdatacontest"
    "contest-football-nfl-dev" = "sportsdatacontest"
    "franchise-football-ncaa-dev" = "sportsdatafranchise"
    "franchise-football-nfl-dev" = "sportsdatafranchise"
    "notification-dev" = "sportsdatanotification"
    "player-football-ncaa-dev" = "sportsdataplayer"
    "player-football-nfl-dev" = "sportsdataplayer"
    "producer-football-ncaa-dev" = "sportsdataproducer"
    "producer-football-nfl-dev" = "sportsdataproducer"
    "provider-football-ncaa-dev" = "sportsdataprovider"
    "provider-football-nfl-dev" = "sportsdataprovider"
    "season-football-ncaa-dev" = "sportsdataseason"
    "season-football-nfl-dev" = "sportsdataseason"
    "venue-dev" = "sportsdatavenue"
} 