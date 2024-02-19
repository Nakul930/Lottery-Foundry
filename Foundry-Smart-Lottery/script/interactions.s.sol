//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Script,console} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";



contract CreateSubscription is Script{
    function createSubscriptionUsingConfig() public returns(uint64){
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,,,,,uint256 deployKey)= helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator,deployKey);
    }
    function createSubscription(address vrfCoordinator,uint256 deployKey) public returns(uint64){
        console.log("Creating Subscription on ChainId:", block.chainid);
        vm.startBroadcast(deployKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your SubId is:",subId);
        console.log("Please update subscription in HelperConfig.s.sol");
        return subId;
    }
    function run() external returns(uint64){
         return createSubscriptionUsingConfig();
    }
}
contract FundSubscription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;
    function fundSubscriptionUsingConfig() public{
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,,uint64 subId, , address link,uint256 deployKey )= helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator,subId,link,deployKey);
    }
    function fundSubscription(address vrfCoordinator,uint64 subId, address link,uint256 deployKey) public {
        console.log("Funding Subscription;", subId);
        console.log("Using Vrf Coordinator;", vrfCoordinator);
        console.log("on ChainId:" ,block.chainid);
        if(block.chainid==31337){
            vm.startBroadcast(deployKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId,FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else{
            vm.startBroadcast(deployKey);
            LinkToken(link).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subId));
            vm.stopBroadcast();
        }
    }
    
    function run() external {
        fundSubscriptionUsingConfig();
    }
}
contract AddConsumer is Script{
    function addConsumer(address raffle, address vrfCoordinator, uint64 subId,uint256 deployKey) public{
        console.log("Adding consumer Contract:",raffle);
        console.log("Using Vrf Coordinator:",vrfCoordinator);
        console.log("On ChainId:",block.chainid);
        vm.startBroadcast(deployKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId,raffle);
        vm.stopBroadcast();
    }

    function AddConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,,uint64 subId,, ,uint256 deployerKey)= helperConfig.activeNetworkConfig();
        addConsumer(raffle,vrfCoordinator,subId,deployerKey);
    }
    function run() external{
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        AddConsumerUsingConfig(raffle);
    }

}