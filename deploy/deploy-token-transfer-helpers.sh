$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY WETH)

# $(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY RoyaltyEngine --constructor-args "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY RoyaltyEngine --constructor-args "0xbA79a22A4b8018caFDC24201ab934c9AdF6903d7")

$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ERC20TransferHelper --constructor-args "0xd73A896034d9CA82D5479a8e1CD57F8d5E1cCFFC")

$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ERC721TransferHelper --constructor-args "0xd73A896034d9CA82D5479a8e1CD57F8d5E1cCFFC")

$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY FlexiBarterOffersV1 --constructor-args "0x8e8De16943cA08ee418719aCA08b14696a66CFd1" "0xFca11C0a6849B9d508b64A65B4732C3335e7AF6a" "0x568e0084E720D5403A2637135f364517df50c6D7" "0x974513f4ed9f80beFFc37Ee9503AE260B63beF13" "0x9ebfF175e4ed8A90D086e5b46F5D73B05d716F7f")
