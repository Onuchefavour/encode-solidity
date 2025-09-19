import { 
  Clarinet, 
  Tx, 
  Chain, 
  Account, 
  types 
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';

Clarinet.test({
  name: "Encode Marketplace: Job Creation Basic Flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const jobCreator = accounts.get('wallet_1')!;

    // Create job
    let block = chain.mineBlock([
      Tx.contractCall(
        'encode-marketplace', 
        'create-job', 
        [
          types.ascii('Web3 Development Project'),
          types.utf8('Comprehensive blockchain frontend'),
          types.uint(5000),
          types.uint(chain.blockHeight + 100)
        ],
        jobCreator.address
      )
    ]);

    block.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "Encode Marketplace: Proposal Submission",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const jobCreator = accounts.get('wallet_1')!;
    const serviceProvider = accounts.get('wallet_2')!;

    // First, create a job
    let block = chain.mineBlock([
      Tx.contractCall(
        'encode-marketplace', 
        'create-job', 
        [
          types.ascii('Web3 Development Project'),
          types.utf8('Comprehensive blockchain frontend'),
          types.uint(5000),
          types.uint(chain.blockHeight + 100)
        ],
        jobCreator.address
      )
    ]);

    // Then submit a proposal
    block = chain.mineBlock([
      Tx.contractCall(
        'encode-marketplace', 
        'submit-work-proposal', 
        [
          types.uint(0),  // Job ID
          types.utf8('Detailed proposal for frontend implementation'),
          types.uint(4500),
          types.uint(chain.blockHeight + 90)
        ],
        serviceProvider.address
      )
    ]);

    block.receipts[0].result.expectOk();
  }
});