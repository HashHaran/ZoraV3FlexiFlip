import { Header } from "../Header";
import { useContractRead, useAccount, useContractWrite } from "wagmi";
import { useState, useEffect } from "react";
import { ReadContractResult } from "@wagmi/core";
import { BigNumber, ethers, utils } from "ethers";

export const CreateOffer = (nft) => {
  interface createOfferCall {
    targetTokenContract: any;
    targetTokenId: any;
    offerTokenAddresses: any;
    isNfts: any;
    offerTokenIds: any;
    amounts: any;
    findersFeeBps: any;
  }

  const [createOffer, setCreateOffer] = useState<createOfferCall>({
    targetTokenContract: "",
    targetTokenId: "",
    offerTokenAddresses: [],
    isNfts: [],
    offerTokenIds: [],
    amounts: [],
    findersFeeBps: "",
  });

  const { data: createOfferData, write: createOfferWrite } = useContractWrite({
    addressOrName: "",
    contractInterface: [],
    functionName: "createOffer",
    args: [
        createOffer.targetTokenContract,
        createOffer.targetTokenId,
        createOffer.offerTokenAddresses,
        createOffer.isNfts,
        createOffer.offerTokenIds,
        createOffer.amounts,

    ],
  });

  const shortenedAddress = (address) => {
    let displayAddress = address?.substr(0, 4) + "..." + address?.substr(-4);
    return displayAddress;
  };

  return (
    <div className="flex flex-row flex-wrap w-fit space-y-1">
      <div className="flex flex-row w-full">
        <input
          className="flex flex-row flex-wrap w-full text-black text-center bg-slate-200 hover:bg-slate-300"
          placeholder="Offer Token Addresses adr1,adr2,adr3..."
          name="createOfferPrice"
          type="number"
          onChange={(e) => {
            e.preventDefault();
            setCreateOffer((current) => {
              return {
                ...current,
                amount: e.target.value.split(","),
              };
            });
          }}
          required
        ></input>
      </div>

      <div className="flex flex-row w-full">
        <input
          className="flex flex-row flex-wrap w-full text-black text-center bg-slate-200 hover:bg-slate-300"
          placeholder="If NFTs, type true, else false, e.g. true,false,true"
          name="createOfferCurrency"
          type="text"
          onChange={(e) => {
            e.preventDefault();
            setCreateOffer((current) => {
              return {
                ...current,
                currency: e.target.value.split(","),
              };
            });
          }}
          required
        ></input>
      </div>

      <div className="flex flex-row w-full">
        <input
          className="flex flex-row flex-wrap w-full text-black text-center bg-slate-200 hover:bg-slate-300"
          placeholder="Amounts, e.g. 1,2,3"
          name="createOfferFindersFeeBps"
          type="text"
          onChange={(e) => {
            e.preventDefault();
            setCreateOffer((current) => {
              return {
                ...current,
                findersFeeBps: e.target.value.split(","),
              };
            });
          }}
          required
        ></input>
      </div>
      <button
        type="button"
        onClick={() => createOfferWrite()}
        className="border-2 border-white border-solid w-full px-2 hover:bg-[#33FF57] hover:text-slate-900"
      >
        CREATE OFFER
      </button>
    </div>
  );
};
