#!/bin/bash
set -e                 # Exit immediately if any command exits with a non-zero status.

# Start skills-ms service
cd skills-ms

# Remove existing container, if necessary
podman rm -f postgres || true

# Start the PostgreSQL container
podman run -d --rm \
    --name postgres \
    -p 127.0.0.1:5432:5432 \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    postgres:alpine

# Wait for PostgreSQL to start completely
echo "Waiting for PostgreSQL for skills-ms to start..."
sleep 5

# Check if the database exists and create it if not
DB_EXISTS=$(podman exec postgres \
    psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='academy-skills'")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Creating database 'academy-skills'..."
    podman exec postgres \
        psql -U postgres \
        -c 'create database "academy-skills";'
else
    echo "Database 'academy-skills' already exists."
fi

podman run -d --rm \
    --replace \
    --name redis \
    -p 127.0.0.1:6379:6379 \
    redis:alpine

echo "Waiting for Redis for skills-ms to start..."
sleep 5

poe migrate
sleep 5

PORT=8001

# Check if the port is used and stop the process
if sudo fuser $PORT/tcp &>/dev/null; then
    echo "Port $PORT in use. Stopping process..."
    sudo fuser -k $PORT/tcp
fi

# Start the API service for skills-ms
nohup poe api > api.log 2>&1 &
echo "API service for skills-ms started in the background."

# Start events-ms service
cd ../events-ms

# Wait for PostgreSQL to start completely
echo "Waiting for PostgreSQL for events-ms to start..."
sleep 5

# Check if the database exists and create it if not
DB_EXISTS=$(podman exec postgres \
    psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='academy-events'")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Creating database 'academy-events'..."
    podman exec postgres \
        psql -U postgres \
        -c 'create database "academy-events";'
else
    echo "Database 'academy-events' already exists."
fi

poe migrate
sleep 5

PORT=8004

# Check if the port is used and stop the process
if sudo fuser $PORT/tcp &>/dev/null; then
    echo "Port $PORT in use. Stopping process..."
    sudo fuser -k $PORT/tcp
fi

# Start the API service for events-ms
nohup poe api > api.log 2>&1 &
echo "API service for events-ms started in the background."

# Start auth-ms service
cd ../auth-ms

# Create the 'academy-auth' database for auth-ms
podman exec postgres \
    psql -U postgres \
    -c 'create database "academy-auth";'

# Install the dependencies for auth-ms.
poe setup

# Run the database migrations for auth-ms.
poe migrate

PORT=8000

# Check if the port is used and stop the process for auth-ms
if sudo fuser $PORT/tcp &>/dev/null; then
    echo "Port $PORT in use. Stopping process..."
    sudo fuser -k $PORT/tcp
fi

# Start the API service for auth-ms
nohup poe api > api.log 2>&1 &
echo "API service for auth-ms started in the background."


#FRONTEND: Default

cd ../frontend

npm install

PORT=3000

if sudo fuser $PORT/tcp &>/dev/null; then
    echo "Port $PORT in use. Stopping process..."
    sudo fuser -k $PORT/tcp
fi

npm run dev > api.log 2>&1 &
echo "Started frontend"

#ADMIN-DASHBOARD: uncomment following lines

#cd ../admin-dashboard

#npm install

#PORT=3000

## Check if the port is used and stop the process for auth-ms
#if sudo fuser $PORT/tcp &>/dev/null; then
    #echo "Port $PORT in use. Stopping process..."
    #sudo fuser -k $PORT/tcp
#fi

#npm run dev > api.log 2>&1 &
#echo "Started admin-dashboard"