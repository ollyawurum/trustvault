# Trust Vault

A production-ready decentralized escrow smart contract for the Stacks blockchain with built-in dispute resolution and reputation tracking.

## Overview

Trust Vault is a secure, gas-optimized escrow system that enables trustless transactions between parties. It features a three-party escrow mechanism with automated dispute resolution, on-chain reputation tracking, and emergency withdrawal capabilities.

## Features

- **🔒 Secure Escrow System**: Three-party escrow with buyer, seller, and arbiter roles
- **⚖️ Dispute Resolution**: Arbiter-based voting system for conflict resolution
- **⭐ Reputation Tracking**: On-chain reputation system tracking completed and disputed deals
- **💰 Fee Management**: 0.5% platform fee on successful transactions
- **🚨 Emergency Withdrawal**: Timeout-based fund recovery after 60 days
- **⛽ Gas Optimized**: Efficient storage patterns and minimal computational overhead
- **🛡️ Battle-tested Security**: Comprehensive input validation and access controls

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) >= v1.7.0
- [Node.js](https://nodejs.org/) >= v16 (for running tests)
- [Stacks CLI](https://docs.stacks.co/docs/cli) (optional, for additional tooling)

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/yourusername/trust-vault.git
cd trust-vault
```

2. Install Clarinet (if not already installed):
```bash
curl -L https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-linux-x64.tar.gz | tar xz
chmod +x ./clarinet
sudo mv ./clarinet /usr/local/bin
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

## Usage

### Creating an Escrow

```clarity
(contract-call? .trust-vault create-escrow 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; seller address
    'SP3FGQ8Z7JY9BWYZ5WM53E0M9NK7WHJF0691NZ159  ;; arbiter address
    u1000000  ;; amount in microSTX (1 STX)
    (+ burn-block-height u1000)  ;; deadline (current block + 1000)
    u"Payment for web development services")  ;; description
```

### Funding an Escrow

```clarity
;; Buyer funds the escrow (amount + 0.5% fee)
(contract-call? .trust-vault fund-escrow u1)  ;; escrow ID
```

### Completing a Transaction

```clarity
;; Buyer releases funds to seller
(contract-call? .trust-vault complete-escrow u1)
```

### Handling Disputes

```clarity
;; Either party can initiate a dispute
(contract-call? .trust-vault initiate-dispute u1)

;; Arbiter votes on the outcome
(contract-call? .trust-vault vote-dispute u1 true)  ;; true = refund buyer, false = pay seller
```

## Contract Functions

### Read-Only Functions

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `get-escrow` | Get escrow details | `escrow-id: uint` | Escrow data or none |
| `get-user-reputation` | Get user reputation stats | `user: principal` | Reputation record |
| `calculate-fee` | Calculate platform fee | `amount: uint` | Fee amount |
| `get-total-fees` | Get accumulated fees | None | Total fees collected |
| `has-voted` | Check if arbiter voted | `escrow-id: uint, voter: principal` | Boolean |

### Public Functions

| Function | Description | Authorized Caller |
|----------|-------------|-------------------|
| `create-escrow` | Create new escrow | Anyone (becomes buyer) |
| `fund-escrow` | Fund the escrow | Buyer only |
| `complete-escrow` | Release funds to seller | Buyer only |
| `initiate-dispute` | Start dispute process | Buyer or Seller |
| `vote-dispute` | Vote on dispute outcome | Arbiter only |
| `emergency-withdraw` | Withdraw after timeout | Buyer only |
| `withdraw-fees` | Withdraw platform fees | Contract owner only |
| `update-emergency-timeout` | Update timeout period | Contract owner only |

## Escrow Status Codes

- `1` - PENDING: Escrow created, awaiting funding
- `2` - FUNDED: Escrow funded, awaiting completion
- `3` - COMPLETED: Transaction completed successfully
- `4` - DISPUTED: Dispute initiated, awaiting arbiter decision
- `5` - REFUNDED: Funds returned to buyer
- `6` - RESOLVED: Dispute resolved in seller's favor

## Security Considerations

### Access Control
- Role-based permissions ensure only authorized parties can perform actions
- Contract owner privileges limited to fee withdrawal and timeout updates

### Input Validation
- All inputs validated for correctness and safety
- Protection against common attack vectors

### Fund Safety
- Funds held securely in contract until conditions are met
- Emergency withdrawal mechanism prevents permanent fund lock

## Testing

Run the comprehensive test suite:

```bash
clarinet test
```

Individual test categories:
- Escrow creation and validation
- Funding mechanisms
- Dispute resolution flow
- Emergency withdrawal
- Fee calculations
- Access control
- Reputation system

## Deployment

### Testnet Deployment

```bash
# Generate deployment plan
clarinet deployment generate --testnet

# Deploy to testnet
clarinet deployment apply --testnet
```

### Mainnet Deployment

```bash
# Generate mainnet deployment
clarinet deployment generate --mainnet

# Deploy to mainnet (requires STX for fees)
clarinet deployment apply --mainnet
```

## Gas Optimization

The contract implements several gas optimization techniques:
- Efficient storage patterns using maps instead of lists
- Minimal computational complexity in core functions
- Batch operations where possible
- Optimized data structures

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Audit Status

⚠️ **Note**: This contract has not yet been formally audited. Use in production at your own risk. We recommend getting a professional audit before mainnet deployment.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Clarity](https://clarity-lang.org/)
- Tested with [Clarinet](https://github.com/hirosystems/clarinet)
- Deployed on [Stacks](https://www.stacks.co/)

## Roadmap

- [ ] Multi-signature arbiter support
- [ ] Milestone-based escrows
- [ ] Token escrow support (SIP-010)
- [ ] Advanced reputation algorithms
- [ ] Integration with DeFi protocols
- [ ] Mobile SDK
- [ ] Web interface

---

Built with ❤️ for the Stacks ecosystem
