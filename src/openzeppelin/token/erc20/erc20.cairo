//! SPDX-License-Identifier: MIT
//! OpenZeppelin Contracts for Cairo v0.8.0-beta.1 (token/erc20/erc20.cairo)
//!
//! # ERC20 Contract and Implementation
//!
//! This ERC20 contract includes both a library and a basic preset implementation.
//! The library is agnostic regarding how tokens are created; however,
//! the preset implementation sets the initial supply in the constructor.
//! A derived contract can use [_mint](_mint) to create a different supply mechanism.
#[starknet::contract]
mod ERC20 {
    use integer::BoundedInt;
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::interface::IERC20CamelOnly;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC20_name: felt252,
        ERC20_symbol: felt252,
        ERC20_decimals: u8,
        ERC20_total_supply: u256,
        ERC20_balances: LegacyMap<ContractAddress, u256>,
        ERC20_allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Copy, Drop, PartialEq, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    /// Emitted when tokens are moved from address `from` to address `to`.
    #[derive(Copy, Drop, PartialEq, starknet::Event)]
    struct Transfer {
        // #[key] - Not indexed, to maintain backward compatibility.
        from: ContractAddress,
        // #[key] - Not indexed, to maintain backward compatibility.
        to: ContractAddress,
        value: u256
    }

    /// Emitted when the allowance of a `spender` for an `owner` is set by a call
    /// to [approve](approve). `value` is the new allowance.
    #[derive(Copy, Drop, PartialEq, starknet::Event)]
    struct Approval {
        // #[key] - Not indexed, to maintain backward compatibility.
        owner: ContractAddress,
        // #[key] - Not indexed, to maintain backward compatibility.
        spender: ContractAddress,
        value: u256
    }

    mod Errors {
        const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
        const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
        const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
    }

    //
    // Hooks
    //

    #[generate_trait]
    impl ERC20HooksImpl of ERC20HooksTrait {
        fn _before_update(
            ref self: ContractState, from: ContractAddress, recipient: ContractAddress, amount: u256
        ) {}

        fn _after_update(
            ref self: ContractState, from: ContractAddress, recipient: ContractAddress, amount: u256
        ) {}
    }

    /// Initializes the state of the ERC20 contract. This includes setting the
    /// initial supply of tokens as well as the recipient of the initial supply.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.initializer(name, symbol, decimals);
        self._mint(recipient, initial_supply);
    }

    //
    // External
    //

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        /// Returns the name of the token.
        fn name(self: @ContractState) -> felt252 {
            self.ERC20_name.read()
        }

        /// Returns the ticker symbol of the token, usually a shorter version of the name.
        fn symbol(self: @ContractState) -> felt252 {
            self.ERC20_symbol.read()
        }

        /// Returns the number of decimals used to get its user representation.
        fn decimals(self: @ContractState) -> u8 {
            self.ERC20_decimals.read()
        }

        /// Returns the value of tokens in existence.
        fn total_supply(self: @ContractState) -> u256 {
            self.ERC20_total_supply.read()
        }

        /// Returns the amount of tokens owned by `account`.
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.ERC20_balances.read(account)
        }

        /// Returns the remaining number of tokens that `spender` is
        /// allowed to spend on behalf of `owner` through [transfer_from](transfer_from).
        /// This is zero by default.
        /// This value changes when [approve](approve) or [transfer_from](transfer_from)
        /// are called.
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.ERC20_allowances.read((owner, spender))
        }

        /// Moves `amount` tokens from the caller's token balance to `to`.
        /// Emits a [Transfer](Transfer) event.
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        /// Moves `amount` tokens from `from` to `to` using the allowance mechanism.
        /// `amount` is then deducted from the caller's allowance.
        /// Emits a [Transfer](Transfer) event.
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// Sets `amount` as the allowance of `spender` over the caller’s tokens.
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
    }

    /// Increases the allowance granted from the caller to `spender` by `added_value`.
    /// Emits an [Approval](Approval) event indicating the updated allowance.
    #[external(v0)]
    fn increase_allowance(
        ref self: ContractState, spender: ContractAddress, added_value: u256
    ) -> bool {
        self._increase_allowance(spender, added_value)
    }

    /// Decreases the allowance granted from the caller to `spender` by `subtracted_value`.
    /// Emits an [Approval](Approval) event indicating the updated allowance.
    #[external(v0)]
    fn decrease_allowance(
        ref self: ContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool {
        self._decrease_allowance(spender, subtracted_value)
    }

    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl of IERC20CamelOnly<ContractState> {
        /// Camel case support.
        /// See [total_supply](total-supply).
        fn totalSupply(self: @ContractState) -> u256 {
            ERC20Impl::total_supply(self)
        }

        /// Camel case support.
        /// See [balance_of](balance_of).
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            ERC20Impl::balance_of(self, account)
        }

        /// Camel case support.
        /// See [transfer_from](transfer_from).
        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20Impl::transfer_from(ref self, sender, recipient, amount)
        }
    }

    /// Camel case support.
    /// See [increase_allowance](increase_allowance).
    #[external(v0)]
    fn increaseAllowance(
        ref self: ContractState, spender: ContractAddress, addedValue: u256
    ) -> bool {
        increase_allowance(ref self, spender, addedValue)
    }

    /// Camel case support.
    /// See [decrease_allowance](decrease_allowance).
    #[external(v0)]
    fn decreaseAllowance(
        ref self: ContractState, spender: ContractAddress, subtractedValue: u256
    ) -> bool {
        decrease_allowance(ref self, spender, subtractedValue)
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Initializes the contract by setting the token name and symbol.
        /// To prevent reinitialization, this should only be used inside of a contract constructor.
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252, decimals_: u8) {
            self.ERC20_name.write(name_);
            self.ERC20_symbol.write(symbol_);
            self.ERC20_decimals.write(decimals_);
        }

        /// Internal method that moves an `amount` of tokens from `from` to `to`.
        /// Emits a [Transfer](Transfer) event.
        fn _transfer<impl Hooks: ERC20HooksTrait>(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!recipient.is_zero(), Errors::TRANSFER_TO_ZERO);
            self._update::<Hooks>(sender, recipient, amount);
        }

        /// Internal method that sets `amount` as the allowance of `spender` over the
        /// `owner`s tokens.
        /// Emits an [Approval](Approval) event.
        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), Errors::APPROVE_FROM_ZERO);
            assert(!spender.is_zero(), Errors::APPROVE_TO_ZERO);
            self.ERC20_allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        /// Creates a `value` amount of tokens and assigns them to `account`.
        /// Emits a [Transfer](Transfer) event with `from` set to the zero address.
        fn _mint<impl Hooks: ERC20HooksTrait>(
            ref self: ContractState, recipient: ContractAddress, amount: u256
        ) {
            assert(!recipient.is_zero(), Errors::MINT_TO_ZERO);
            self._update::<Hooks>(Zeroable::zero(), recipient, amount);
        }

        /// Destroys a `value` amount of tokens from `account`.
        /// Emits a [Transfer](Transfer) event with `to` set to the zero address.
        fn _burn<impl Hooks: ERC20HooksTrait>(
            ref self: ContractState, account: ContractAddress, amount: u256
        ) {
            assert(!account.is_zero(), Errors::BURN_FROM_ZERO);
            self._update::<Hooks>(account, Zeroable::zero(), amount);
        }

        /// Internal method for the external [increase_allowance](increase_allowance).
        /// Emits an [Approval](Approval) event indicating the updated allowance.
        fn _increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self
                ._approve(
                    caller, spender, self.ERC20_allowances.read((caller, spender)) + added_value
                );
            true
        }

        /// Internal method for the external [decrease_allowance](decrease_allowance).
        /// Emits an [Approval](Approval) event indicating the updated allowance.
        fn _decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self
                ._approve(
                    caller,
                    spender,
                    self.ERC20_allowances.read((caller, spender)) - subtracted_value
                );
            true
        }

        /// Updates `owner`s allowance for `spender` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance.
        /// Possibly emits an [Approval](Approval) event.
        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.ERC20_allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }

        /// Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints
        // (or burns) if `from` (or `to`) is the zero address. All customizations to transfers,
        // mints, and burns should be done by overriding this function.
        fn _update<impl Hooks: ERC20HooksTrait>(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            Hooks::_before_update(ref self, from, to, amount);

            let zero_address = Zeroable::zero();
            if (from == zero_address) {
                self.ERC20_total_supply.write(self.ERC20_total_supply.read() + amount);
            } else {
                self.ERC20_balances.write(from, self.ERC20_balances.read(from) - amount);
            }

            if (to == zero_address) {
                self.ERC20_total_supply.write(self.ERC20_total_supply.read() - amount);
            } else {
                self.ERC20_balances.write(to, self.ERC20_balances.read(to) + amount);
            }

            self.emit(Transfer { from, to, value: amount });

            Hooks::_after_update(ref self, from, to, amount);
        }
    }
}
