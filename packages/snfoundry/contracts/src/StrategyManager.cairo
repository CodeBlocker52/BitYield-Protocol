use starknet::ContractAddress;

// Public structs that need to be exported from the interface
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct StrategyPerformance {
    pub total_deposited: u256,
    pub total_withdrawn: u256,
    pub yield_earned: u256,
    pub last_apy: u32,
    pub last_update: u64,
}

#[derive(Drop, Serde)]
pub struct RebalanceAction {
    pub from_strategy: felt252,
    pub to_strategy: felt252,
    pub amount: u256,
}

#[starknet::interface]
pub trait IStrategyManager<TContractState> {
    fn calculate_optimal_allocation(self: @TContractState, total_assets: u256) -> (u256, u256, u256);
    fn needs_rebalance(self: @TContractState, total_assets: u256) -> bool;
    fn rebalance(ref self: TContractState, total_assets: u256) -> Array<RebalanceAction>;
    fn harvest_yield(ref self: TContractState) -> u256;
    fn update_targets(ref self: TContractState, vesu_bps: u32, troves_bps: u32, idle_bps: u32);
    fn set_rebalancer(ref self: TContractState, rebalancer: ContractAddress, authorized: bool);
    fn get_targets(self: @TContractState) -> (u32, u32, u32);
    fn get_strategy_performance(self: @TContractState, strategy: felt252) -> StrategyPerformance;
    fn get_cumulative_yield(self: @TContractState) -> u256;
    fn calculate_apy(self: @TContractState) -> u32;
    fn update_rebalance_config(ref self: TContractState, threshold_bps: u32, min_interval: u64);
}

#[starknet::contract]
mod StrategyManager {
    use super::{StrategyPerformance, RebalanceAction};
    use starknet::{ContractAddress,  get_caller_address, get_block_timestamp};
    use core::num::traits::Zero;
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        vault: ContractAddress,
        vesu_adapter: ContractAddress,
        troves_adapter: ContractAddress,
        vesu_target_bps: u32,
        troves_target_bps: u32,
        idle_target_bps: u32,
        rebalance_threshold_bps: u32,
        min_rebalance_interval: u64,
        last_rebalance_time: u64,
        last_total_assets: u256,
        last_yield_update: u64,
        cumulative_yield: u256,
        vesu_performance: StrategyPerformance,
        troves_performance: StrategyPerformance,
        authorized_rebalancers: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        StrategyAllocated: StrategyAllocated,
        RebalanceExecuted: RebalanceExecuted,
        TargetsUpdated: TargetsUpdated,
        YieldHarvested: YieldHarvested,
        RebalancerAuthorized: RebalancerAuthorized,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StrategyAllocated {
        #[key]
        pub strategy: felt252,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RebalanceExecuted {
        pub vesu_allocation: u256,
        pub troves_allocation: u256,
        pub idle_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TargetsUpdated {
        pub vesu_target_bps: u32,
        pub troves_target_bps: u32,
        pub idle_target_bps: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct YieldHarvested {
        pub total_yield: u256,
        pub vesu_yield: u256,
        pub troves_yield: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RebalancerAuthorized {
        #[key]
        pub rebalancer: ContractAddress,
        pub authorized: bool,
    }

    // Error constants
    pub const UNAUTHORIZED: felt252 = 'Unauthorized caller';
    pub const INVALID_ALLOCATION: felt252 = 'Invalid allocation targets';
    pub const REBALANCE_TOO_SOON: felt252 = 'Rebalance interval not met';
    pub const THRESHOLD_NOT_MET: felt252 = 'Threshold not exceeded';
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        vault: ContractAddress,
        vesu_adapter: ContractAddress,
        troves_adapter: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.vault.write(vault);
        self.vesu_adapter.write(vesu_adapter);
        self.troves_adapter.write(troves_adapter);
        
        // Default allocation: 70% Vesu, 30% Troves, 0% idle
        self.vesu_target_bps.write(7000);
        self.troves_target_bps.write(3000);
        self.idle_target_bps.write(0);
        
        // Default rebalance threshold: 5%
        self.rebalance_threshold_bps.write(500);
        
        // Min rebalance interval: 1 hour
        self.min_rebalance_interval.write(3600);
        
        self.last_rebalance_time.write(get_block_timestamp());
        
        // Initialize performance tracking
        let empty_performance = StrategyPerformance {
            total_deposited: 0,
            total_withdrawn: 0,
            yield_earned: 0,
            last_apy: 0,
            last_update: 0,
        };
        self.vesu_performance.write(empty_performance);
        self.troves_performance.write(empty_performance);
        
        self.last_total_assets.write(0);
        self.last_yield_update.write(get_block_timestamp());
        self.cumulative_yield.write(0);
    }

    #[abi(embed_v0)]
    impl StrategyManagerImpl of super::IStrategyManager<ContractState> {
        fn calculate_optimal_allocation(self: @ContractState, total_assets: u256) -> (u256, u256, u256) {
            let vesu_target = (total_assets * self.vesu_target_bps.read().into()) / 10000;
            let troves_target = (total_assets * self.troves_target_bps.read().into()) / 10000;
            let idle_target = total_assets - vesu_target - troves_target;
            
            (vesu_target, troves_target, idle_target)
        }

        fn needs_rebalance(self: @ContractState, total_assets: u256) -> bool {
            // Check time interval
            let current_time = get_block_timestamp();
            let time_since_last = current_time - self.last_rebalance_time.read();
            if time_since_last < self.min_rebalance_interval.read() {
                return false;
            }
            
            // Check if deviation exceeds threshold
            let (vesu_target, _troves_target, _) = self.calculate_optimal_allocation(total_assets);
            
            // TODO: Get actual allocations from adapters
            let vesu_actual: u256 = 0;
            
            let vesu_deviation = if vesu_actual > vesu_target {
                ((vesu_actual - vesu_target) * 10000) / total_assets
            } else {
                ((vesu_target - vesu_actual) * 10000) / total_assets
            };
            
            let threshold: u256 = self.rebalance_threshold_bps.read().into();
            vesu_deviation > threshold
        }

        fn rebalance(ref self: ContractState, total_assets: u256) -> Array<RebalanceAction> {
            self._assert_can_rebalance();
            
            let (vesu_target, troves_target, idle_target) = self.calculate_optimal_allocation(total_assets);
            
            // TODO: Get current allocations from adapters
            let vesu_current: u256 = 0;
            let troves_current: u256 = 0;
            let idle_current: u256 = 0;
            
            let mut actions: Array<RebalanceAction> = ArrayTrait::new();
            
            // Calculate rebalancing actions
            if vesu_current < vesu_target {
                let amount_needed = vesu_target - vesu_current;
                // Withdraw from idle or troves
                if idle_current >= amount_needed {
                    actions.append(RebalanceAction {
                        from_strategy: 'idle',
                        to_strategy: 'vesu',
                        amount: amount_needed,
                    });
                } else if troves_current > troves_target {
                    let amount_from_troves = troves_current - troves_target;
                    actions.append(RebalanceAction {
                        from_strategy: 'troves',
                        to_strategy: 'vesu',
                        amount: amount_from_troves,
                    });
                }
            }
            
            // Similar logic for troves...
            
            self.last_rebalance_time.write(get_block_timestamp());
            
            self.emit(RebalanceExecuted {
                vesu_allocation: vesu_target,
                troves_allocation: troves_target,
                idle_amount: idle_target,
                timestamp: get_block_timestamp(),
            });
            
            actions
        }

        fn harvest_yield(ref self: ContractState) -> u256 {
            self._assert_authorized();
            
            // TODO: Call harvest on adapters
            let vesu_yield: u256 = 0;
            let troves_yield: u256 = 0;
            let total_yield = vesu_yield + troves_yield;
            
            // Update performance tracking
            let current_cumulative = self.cumulative_yield.read();
            self.cumulative_yield.write(current_cumulative + total_yield);
            self.last_yield_update.write(get_block_timestamp());
            
            self.emit(YieldHarvested {
                total_yield,
                vesu_yield,
                troves_yield,
                timestamp: get_block_timestamp(),
            });
            
            total_yield
        }

        fn update_targets(
            ref self: ContractState,
            vesu_bps: u32,
            troves_bps: u32,
            idle_bps: u32,
        ) {
            self.ownable.assert_only_owner();
            assert!(vesu_bps + troves_bps + idle_bps == 10000, "{}", INVALID_ALLOCATION);
            
            self.vesu_target_bps.write(vesu_bps);
            self.troves_target_bps.write(troves_bps);
            self.idle_target_bps.write(idle_bps);
            
            self.emit(TargetsUpdated {
                vesu_target_bps: vesu_bps,
                troves_target_bps: troves_bps,
                idle_target_bps: idle_bps,
            });
        }

        fn set_rebalancer(ref self: ContractState, rebalancer: ContractAddress, authorized: bool) {
            self.ownable.assert_only_owner();
            assert!(!rebalancer.is_zero(), "{}", ZERO_ADDRESS);
            
            self.authorized_rebalancers.entry(rebalancer).write(authorized);
            
            self.emit(RebalancerAuthorized { rebalancer, authorized });
        }

        fn get_targets(self: @ContractState) -> (u32, u32, u32) {
            (
                self.vesu_target_bps.read(),
                self.troves_target_bps.read(),
                self.idle_target_bps.read(),
            )
        }

        fn get_strategy_performance(self: @ContractState, strategy: felt252) -> StrategyPerformance {
            if strategy == 'vesu' {
                self.vesu_performance.read()
            } else if strategy == 'troves' {
                self.troves_performance.read()
            } else {
                // Return empty performance
                StrategyPerformance {
                    total_deposited: 0,
                    total_withdrawn: 0,
                    yield_earned: 0,
                    last_apy: 0,
                    last_update: 0,
                }
            }
        }

        fn get_cumulative_yield(self: @ContractState) -> u256 {
            self.cumulative_yield.read()
        }

        fn calculate_apy(self: @ContractState) -> u32 {
            let current_assets = self.last_total_assets.read();
            let previous_assets = current_assets;
            
            if previous_assets == 0 {
                return 0;
            }
            
            let time_elapsed = get_block_timestamp() - self.last_yield_update.read();
            if time_elapsed == 0 {
                return 0;
            }
            
            // APY = (current - previous) / previous * (365 days / elapsed time) * 10000
            let gain = if current_assets > previous_assets {
                current_assets - previous_assets
            } else {
                0
            };
            
            let apy = (gain * 10000 * 31536000) / (previous_assets * time_elapsed.into());
            apy.try_into().unwrap_or(0)
        }

        fn update_rebalance_config(
            ref self: ContractState,
            threshold_bps: u32,
            min_interval: u64,
        ) {
            self.ownable.assert_only_owner();
            self.rebalance_threshold_bps.write(threshold_bps);
            self.min_rebalance_interval.write(min_interval);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_authorized(self: @ContractState) {
            let caller = get_caller_address();
            let is_owner = caller == self.ownable.owner();
            let is_authorized = self.authorized_rebalancers.entry(caller).read();
            assert!(is_owner || is_authorized, "{}", UNAUTHORIZED);
        }

        fn _assert_can_rebalance(self: @ContractState) {
            self._assert_authorized();
            
            let current_time = get_block_timestamp();
            let time_since_last = current_time - self.last_rebalance_time.read();
            assert!(time_since_last >= self.min_rebalance_interval.read(), "{}", REBALANCE_TOO_SOON);
        }
    }
}