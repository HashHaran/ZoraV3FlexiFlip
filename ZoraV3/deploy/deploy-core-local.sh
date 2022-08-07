#!/bin/bash

# args: 'overwrite' or 'dontoverwrite' to redeploy and commit new addresses
# env: ETHERSCAN_API_KEY, CHAIN_ID, RPC_URL, PRIVATE_KEY, WALLET_ADDRESS, REGISTRAR, FEE_SETTINGS_OWNER

if [ "$1" != "overwrite" ] && [ "$1" != "" ]
then
    echo "Invalid overwrite argument. Exiting."
    exit 1
fi

if [ "$ETHERSCAN_API_KEY" = "" ]
then
    echo "Missing ETHERSCAN_API_KEY. Exiting."
    exit 1
fi

if [ "$CHAIN_ID" = "" ]
then
    echo "Missing CHAIN_ID. Exiting."
    exit 1
fi

if [ "$RPC_URL" = "" ]
then
    echo "Missing RPC_URL. Exiting."
    exit 1
fi

if [ "$PRIVATE_KEY" = "" ]
then
    echo "Missing PRIVATE_KEY. Exiting."
    exit 1
fi

if [ "$WALLET_ADDRESS" = "" ]
then
    echo "Missing WALLET_ADDRESS. Exiting."
    exit 1
fi

if [ "$REGISTRAR" = "" ]
then
    echo "Missing REGISTRAR. Exiting."
    exit 1
fi

if [ "$FEE_SETTINGS_OWNER" = "" ]
then
    echo "Missing FEE_SETTINGS_OWNER. Exiting."
    exit 1
fi

ADDRESSES_FILENAME="addresses/$CHAIN_ID.json"
echo "Checking for existing contract addresses"
if EXISTING_ADDRESS=$(test -f "$ADDRESSES_FILENAME" && cat "$ADDRESSES_FILENAME" | python3 -c "import sys, json; print(json.load(sys.stdin)['ZoraProtocolFeeSettings'])" 2> /dev/null)
then
    echo "ZoraProtocolFeeSettings already exists on chain $CHAIN_ID at $EXISTING_ADDRESS."
    if [ "$1" != "overwrite" ]
    then
        echo "Exiting."
        exit 1
    else
        echo "Continuing."
    fi
fi
if EXISTING_ADDRESS=$(test -f "$ADDRESSES_FILENAME" && cat "$ADDRESSES_FILENAME" | python3 -c "import sys, json; print(json.load(sys.stdin)['ZoraModuleManager'])" 2> /dev/null)
then
    echo "ZoraModuleManager already exists on chain $CHAIN_ID at $EXISTING_ADDRESS."
    if [ "$1" != "overwrite" ]
    then
        echo "Exiting."
        exit 1
    else
        echo "Continuing."
    fi
fi

echo ""


echo "Deploying ZoraProtocolFeeSettings..."
FEE_SETTINGS_DEPLOY_OUTPUT=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ZoraProtocolFeeSettings)
FEE_SETTINGS_ADDR=$(echo $FEE_SETTINGS_DEPLOY_OUTPUT | rev | cut -d " " -f4 | rev)
if [[ $FEE_SETTINGS_ADDR =~ ^0x[0-9a-fA-F]{40}$ ]]
then
    echo "ZoraProtocolFeeSettings deployed to $FEE_SETTINGS_ADDR"
else
    echo "Could not find contract address in forge output"
    exit 1
fi
FEE_SETTINGS_ADDR=$(cast --to-checksum-address $FEE_SETTINGS_ADDR)

echo "$FEE_SETTINGS_ADDR"


echo "Deploying ZoraModuleManager..."
MODULE_MANAGER_DEPLOY_OUTPUT=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ZoraModuleManager --constructor-args "$REGISTRAR" "$FEE_SETTINGS_ADDR")
ZORA_MODULE_MANAGER_ADDR=$(echo $MODULE_MANAGER_DEPLOY_OUTPUT | rev | cut -d " " -f4 | rev)
if [[ $ZORA_MODULE_MANAGER_ADDR =~ ^0x[0-9a-fA-F]{40}$ ]]
then
    echo "ZoraModuleManager deployed to $ZORA_MODULE_MANAGER_ADDR"
else
    echo "Could not find contract address in forge output"
    echo "$MODULE_MANAGER_DEPLOY_OUTPUT"
    exit 1
fi

ZORA_MODULE_MANAGER_ADDR=$(cast --to-checksum-address $ZORA_MODULE_MANAGER_ADDR)

echo "ZORA_MODULE_MANAGER_ADDR:$ZORA_MODULE_MANAGER_ADDR"
echo "FEE_SETTINGS_ADDR:$FEE_SETTINGS_ADDR"

#Manualy ececute the below CLI commands without using environment variables for contract address and arguements
# FEE_SETTINGS_INIT_OUTPUT=$(cast send --from $WALLET_ADDRESS --private-key $PRIVATE_KEY $FEE_SETTINGS_ADDR "init(address,address)" "$ZORA_MODULE_MANAGER_ADDR" "0x0000000000000000000000000000000000000000" --rpc-url $RPC_URL)
# FEE_SETTINGS_INIT_TX_HASH=$(echo $FEE_SETTINGS_INIT_OUTPUT | rev | cut -d " " -f5 | rev | tr -d '"')
# FEE_SETTINGS_INIT_TX_STATUS=$(echo $FEE_SETTINGS_INIT_OUTPUT | rev | cut -d " " -f7 | rev | tr -d '"')
# if [ $FEE_SETTINGS_INIT_TX_STATUS != "0x1" ]
# then
#     echo "Transaction $FEE_SETTINGS_INIT_TX_HASH did not succeed. Exiting."
#     exit 1
# else
#     echo "ZoraProtocolFeeSettings.init transaction $FEE_SETTINGS_INIT_TX_HASH succeeded."
# fi

# FEE_SETTINGS_SET_OWNER_OUTPUT=$(cast send --from $WALLET_ADDRESS --private-key $PRIVATE_KEY $FEE_SETTINGS_ADDR "setOwner(address)" "$FEE_SETTINGS_OWNER" --rpc-url $RPC_URL)
# FEE_SETTINGS_SET_OWNER_TX_HASH=$(echo $FEE_SETTINGS_SET_OWNER_OUTPUT | rev | cut -d " " -f5 | rev | tr -d '"')
# FEE_SETTINGS_SET_OWNER_TX_STATUS=$(echo $FEE_SETTINGS_SET_OWNER_OUTPUT | rev | cut -d " " -f7 | rev | tr -d '"')
# if [ $FEE_SETTINGS_SET_OWNER_TX_STATUS != "0x1" ]
# then
#     echo "Transaction $FEE_SETTINGS_SET_OWNER_TX_HASH did not succeed. Exiting."
#     exit 1
# else
#     echo "ZoraProtocolFeeSettings.setOwner transaction $FEE_SETTINGS_SET_OWNER_TX_HASH succeeded."
# fi

# python3 ./deploy/update-addresses.py $CHAIN_ID ZoraProtocolFeeSettings $FEE_SETTINGS_ADDR ZoraModuleManager $ZORA_MODULE_MANAGER_ADDR

# echo ""
# echo "Done."
