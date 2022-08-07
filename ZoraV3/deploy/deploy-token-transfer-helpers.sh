$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY WETH)

# $(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY RoyaltyEngine --constructor-args "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY RoyaltyEngine --constructor-args "0xbA79a22A4b8018caFDC24201ab934c9AdF6903d7")

$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ERC20TransferHelper --constructor-args "0x8b0f53a7F756bF883c2c17B7F47206518b227120")

$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ERC721TransferHelper --constructor-args "0x8b0f53a7F756bF883c2c17B7F47206518b227120")

$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY BarterOffersV1 --constructor-args "0x48f65d3e1E60bE0cA82C19d3CA4Ce5268ccCf0f9" "0xE0cC27826bDfB49C9dD817967A5fB43e93e3477F" "0x1f5D313a4F055aEbe69F5E2119D0801F98436F17" "0x30E149913b5a5ca7B81cD33C56fc66a53E72251e" "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa")
