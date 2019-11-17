
pragma solidity ^0.4.10;
// Contract 1 ***// 1 vulnerability = integer underflow!
/* Integer Underflow: An attacker could call sendToken() with more tokens than they have in their account. 
 This would underflow the attacker’s account making them have way more tokens than they actually have, 
 and possibly overflow the recipient’s account, making the recipient have less tokens! */
contract SimpleToken{
    mapping(address => uint) public balances;
    
    /// @dev Buy token at the price of 1ETH/token.
    function buyToken() payable {
        balances[msg.sender]+=msg.value / 1 ether;
    }
    
    /** @dev Send token.
     *  @param _recipient The recipient.
     *  @param _amount The amount to send.
     */
    function sendToken(address _recipient, uint _amount) {
    ??    require(balances[msg.sender]!=0); // You must have some tokens.
        
        balances[msg.sender]-=_amount; // But what if you have 2 tokens and you send 10? Then would your account go into the negative? This would be interger underflow!
        balances[_recipient]+=_amount;
    }
    
}

//*** Contract 2 ***//
/* Overflow: ‘votesReceived[_proposition]+=NumberVotes
 If an attacker kept adding votes for one proposition in the mapping, then the int would overflow and got to 0, making it look like there have been no votes for that proposition. 
 Ether Division: When buying voting rights, if the user sends an uneven amount of ether then whoever has created the contract will get to keep some ether (1.5 - 1) without giving the user the voting right for it.
  E.g. if the user sent 1.5 ether, than the contract owner would keep 0.5 ether more than he was owed for the 1 voting right the user would receive.*/


contract VoteTwoChoices{
    mapping(address => uint) public votingRights;
    mapping(address => uint) public votesCast;
    mapping(bytes32 => uint) public votesReceived;
    
    /// @dev Get 1 voting right per ETH sent.
    function buyVotingRights() payable {
        votingRights[msg.sender]+=msg.value/(1 ether);
    }
    
    /** @dev Vote with nbVotes for a proposition.
     *  @param _nbVotes The number of votes to cast.
     *  @param _proposition The proposition to vote for.
     */
    function vote(uint _nbVotes, bytes32 _proposition) {
        require(_nbVotes + votesCast[msg.sender]<=votingRights[msg.sender]); // Check you have enough voting rights.
        
        votesCast[msg.sender]+=_nbVotes;
        votesReceived[_proposition]+=_nbVotes;
    }

}

//*** Contract 3 ***// 
// The owner can set the price.
contract BuyToken {
    mapping(address => uint) public balances;
    uint public price=1;
    address public owner=msg.sender;
    
    /** @dev Buy tokens.
     *  @param _amount The amount to buy.
     *  @param _price  The price to buy those in ETH.
     */
    function buyToken(uint _amount, uint _price) payable {
        require(_price>=price); // The price is at least the current price.
        require(_price * _amount * 1 ether <= msg.value); // You have paid at least the total price.
        balances[msg.sender]+=_amount;
    }
    
    /** @dev Set the price, only the owner can do it.
     *  @param _price The new price.
     */
    function setPrice(uint _price) { // What if owner wants to set the price to 0.1, int would not be able to hold a decimal number. jkjk
 owner could lose their private key! Should make the owner a multisig contract, or use a time lock. Or maybe this isn't an issue because the rest of the contract doesn't depend on this function.  
        require(msg.sender==owner);
        price=_price;
    }
}

//*** Contract 4 ***// 
/* Block gas Limit - The for loop currently searching through an array of structs,
 checking for the one that the msg.sender is the ‘owner’ of. It checks each struct,
  and if the struct is the owner’s and is non-empty, then it transfers the money from the struct to the msg.sender. 
  This happens all in one function, which is a problem because transferring ether to a number of accounts is going 
  to take a lot of gas if the for-loop is big, so the transaction may use more gas than the block gas limit allows 
  causing the entire transaction to fail, causing the withdraw() function to be uncallable by anyone who is trying
   to withdraw their money from their account. 
   
   An attacker will add a very large quantity of safes to the array so 
   that it gets so big that the function runs out of gas before checking each safe in the array. Then none of the 
   users will be able to withdraw their money which they are owed from their bank account, and so the contract has 
   ‘denied the user service’ aka =  DOS (Denial of Service) attack with block gas limit. 
*/
contract Store {
    struct Safe {
        address owner;
        uint amount;
    }
    
    Safe[] public safes;
    
    /// @dev Store some ETH.
    function store() payable {
        safes.push(Safe({owner: msg.sender, amount: msg.value}));
    }
    
    /// @dev Take back all the amount stored.
    function take() {
        for (uint i; i<safes.length; ++i) {  
            Safe safe = safes[i];
           if (safe.owner==msg.sender && safe.amount!=0) {  
                  msg.sender.transfer(safe.amount);  
                  safe.amount=0; // 
            }
        }
        
    }
}

//*** Contract 5 ***// 2 vulnerabilities = Constructor should be explicitly labeled constructor, and recordContribution() should be internal function
/* Default visibility - Default visibility of recordContribution() is public,
 it should be private. An attacker could change another user’s or their own recorded
  contribution and make it appear that they have contributed less than they have (or more)
  by calling recordContribution() and passing it another user’s address*/
contract CountContribution{
    mapping(address => uint) public contribution;
    uint public totalContributions;
    address owner=msg.sender;
    
    /// @dev Constructor, count a contribution of 1 ETH to the creator.
    Constructor should be named constructor!
??? function CountContribution() public { // vulnerability because if the name of the contract is changed, then the owner OR anyone else could call this function multiple times and record that they have contributed as many ether as the times they have called it without actually sending any ether. 
        recordContribution(owner, 1 ether);
    }
    
    /// @dev Contribute and record the contribution.
    function contribute() public payable {  // THis is the only function of the contract that will actually be used once the contract has been deployed. 
        recordContribution(msg.sender, msg.value);
    }
    
    /** @dev Record a contribution. To be called by CountContribution and contribute.
     *  @param _user The user who contributed.
     *  @param _amount The amount of the contribution.
     */
    function recordContribution(address _user, uint _amount) {  // could be called by anyone to record a contribution that didn't actually happen. This function should be set to internal. Default visibilty is public. 
        contribution[_user]+=_amount;
        totalContributions+=_amount;
    }
    
}

//*** Contract 6 ***//
/* In sendAllTokens() function, it reads balances[msg.sender]=+balances[recipient] but instead it should read '+='.
 If a user with a balance of 0 calls sendAllTokens, it would set the account of the recipient to 0, 
 therefore any user with a balance of 0 could deprive another user of their entire account balance!
*/
contract Token {
    mapping(address => uint) public balances;
    
    /// @dev Buy token at the price of 1ETH/token.
    function buyToken() payable {
        balances[msg.sender]+=msg.value / 1 ether;
    }
    
    /** @dev Send token.
     *  @param _recipient The recipient.
     *  @param _amount The amount to send.
     */
    function sendToken(address _recipient, uint _amount) {
        require(balances[msg.sender]>=_amount); // You must have some tokens.
        
        balances[msg.sender]-=_amount;
        balances[_recipient]+=_amount;
    }
    
    /** @dev Send all tokens.
     *  @param _recipient The recipient.
     */
    function sendAllTokens(address _recipient) {
        balances[_recipient]=+balances[msg.sender];
        balances[msg.sender]=0;
    }
    
}

//*** Contract 7 ***// 1 vulnerability = Buy() requires user to send exactly 1/3 ether which is impossible. 
/* It is not possible to send 1/3 ether therefore the user will never be able to pay the price required to buy their 3rd object. 
They would need to pay 10^18 / 3 to purchase their third object, which is impossible.
Vulnerabilty 2= The 'constant' modifier has been deprecated, use 'view' instead. */

contract DiscountedBuy {
    uint public basePrice = 1 ether;
    mapping (address => uint) public objectBought;

    /// @dev Buy an object.
    function buy() payable {
        require(msg.value * (1 + objectBought[msg.sender]) == basePrice);
        objectBought[msg.sender]+=1;
    }
    
    /** @dev Return the price you'll need to pay.
     *  @return price The amount you need to pay in wei.
     */
    function price() constant returns(uint price) {  // Constant has been deprecated! 
        return basePrice/(1 + objectBought[msg.sender]);
    }
    
}

//*** Contract 8 ***// 1 vulnerability = Front-Running Attack!!!
/* Front-running: The second player could just look at the transaction pool to see what the 1st player has
 included as a parameter in choose() before calling guess(). */
contract HeadOrTail {
    bool public chosen; // True if head/tail has been chosen.
    bool lastChoiceHead; // True if the choice is head.
    address public lastParty; // The last party who chose.
    
    /** @dev Must be sent 1 ETH.
     *  Choose head or tail to be guessed by the other player.
     *  @param _chooseHead True if head was chosen, false if tail was chosen.
     */
    function choose(bool _chooseHead) payable {
        require(!chosen);
        require(msg.value == 1 ether); // Require that they haven't chosen yet. 
        
        chosen=true; 
        lastChoiceHead=_chooseHead;  //lastChoiceHead holds either true or false, whichever lastParty has chosen. 
        lastParty=msg.sender;
    }
    
    
    function guess(bool _guessHead) payable {
        require(chosen);        //Require that other party has already guessed. BUT at this point they can just check to see what the other party has guessed in thet transaction pool. 
        require(msg.value == 1 ether);
        
        if (_guessHead == lastChoiceHead)  // whoever calls this function could just wait to see to see the other party's guess in the transaction pool.
            msg.sender.transfer(2 ether); 
        else
            lastParty.transfer(2 ether);
            
 ??       chosen=false; // Is this safe to change the state after calling transfer()?
    }
}

//*** Contract 9 ***/ Vulnerability = Re-entrancy in redeem(). 
/*
redeem() function can be used by an attacker to send themselves more ether than is in their vault. 
The redeem function will trigger the fallback function in the attacker's contract, and because it has been called with 'call.value',
 the fallback function has enough gas to call redeem() AGAIN before their balance is set to 0 in the next line of code. 
*/
contract Vault {
    mapping(address => uint) public balances;

    /// @dev Store ETH in the contract.
    function store() payable {
        balances[msg.sender]+=msg.value;
    }
    
    /// @dev Redeem your ETH.
    function redeem() {
        msg.sender.call.value(balances[msg.sender])();  // single function re-entrancy 
        balances[msg.sender]=0;
    }
}

//*** Contract 10 ***//  
/* 
Vulnerability 1: Forcibly sending ether: If partyB forcibly sent ether to the contract, then they could make their guess and call resolve right away, because the only thing the resolve() function requires is that there is 2+ ether in the contract. 

Vulnerability 2: Block Stuffing: After both parties have guessed, if partyB block stuffed and prevented partyA from calling resolve until 1 day had passed, then partyB could call timeOut() and get both the ether. 

Vulnerability 3: Timestamp manipulation on timeOut() function: If partyB were also a miner, then they could set the 'now' property to a day ahead and call the timeOut() function before partyA has had the chance to call resolve, preventing partyA from winning.  
*/
contract HeadTail {
    address public partyA;
    address public partyB;
    bytes32 public commitmentA;
    bool public chooseHeadB;
    uint public timeB;
    
    
    /** @dev Constructor, commit head or tail.
     *  @param _commitmentA is keccak256(chooseHead,randomNumber); // Should it be a hash of the sender's address as well? 
     */
     // If this contructor became a normal function, which partyB could call after already calling guess(), then they could change partyA's guess to whatever they guessed and prevent partyA from winning/getting any ether, but the attacker would only break even. 
    function HeadTail(bytes32 _commitmentA) payable { // This is a constructor, so whoever creates this contract becomes partyA. 
        require(msg.value == 1 ether); // Prevents partyA from calling this function twice and changing their anwser. costs 1 ether to play
        commitmentA=_commitmentA; // Save the choice this player has made
        partyA=msg.sender; 
    }
    
    /** @dev Guess the choice of party A.
     *  @param _chooseHead True if the guess is head, false otherwize.
     */
    function guess(bool _chooseHead) payable {
        require(msg.value == 1 ether); // Pay 1 ether to play
        require(partyB==address(0)); // ensures that partyB is an address account not contract account? 
        
        chooseHeadB=_chooseHead; // save the choice this player has made. 
        timeB=now;
        partyB=msg.sender;
    }
    
    /** @dev Reveal the commited value and send ETH to the winner.
     *  @param _chooseHead True if head was chosen.
     *  @param _randomNumber The random number chosen to obfuscate the commitment.
     */
     // Isn't this commit-reveal scheme suspectible to front-running too? Soon as partyA reveals partyB could re-guess and change anwser. 
     // If someone forcibly sent ether to this address, then balance would be >= 2 and partyA could call this before partyB has guessed. 
    function resolve(bool _chooseHead, uint _randomNumber) {
        require(msg.sender == partyA); // party A is the one to test whether party B guessed correctly. 
        require(keccak256(_chooseHead, _randomNumber) == commitmentA); // Make party A prove that the parameters they have now revealed were the same as they committed before.  
        require(this.balance >= 2 ether); // Require that both people have guessed already. 
  
        if (_chooseHead == chooseHeadB)
            partyB.transfer(2 ether);  
        else
            partyA.transfer(2 ether);
    }
    // ^ isolate each external call into its own transaction that can be initiated by the recipient of the call.
    
    /** @dev Time out party A if it takes more than 1 day to reveal.
     *  Send ETH to party B.
     * */
    function timeOut() {
        // Block Stuffing! Attacker will blockstuff after both have guessed but before other party calls resolve(). 
        // Then after the required timestamp has been mined, they will call timeout().
        require(now > timeB + 1 days);  // TimeStamp manipulation?  If partyB is a miner, then they could change the timestamp on the currenty block to a day ahead and then call this function whether or not the guessed correctly. 
        require(this.balance>=2 ether);
        partyB.transfer(2 ether); // they spend 2 ether everytime and get 2 ether back everytime. 
    }
}

//***Contract 11 ***// 1 vulnerability = Could be affected by the constantiple upgrade? 
// If mstore opcode was used to change value of coffer to a different coffer, or to change value of slot to a different slot. 
contract Coffers {
    struct Coffer {uint[] slots;}
    mapping (address => Coffer) coffers;
    
    /** @dev Create coffers.
     *  @param _extraSlots The amount of slots to add to one's coffer.
     * */
    function createCoffers(uint _extraSlots) {
        Coffer coffer = coffers[msg.sender];
        require(coffer.slots.length+_extraSlots >= _extraSlots);
        coffer.slots.length += _extraSlots; // Makes the slots[] array longer. 
    }
    
    /** @dev Deposit money in one's coffer slot.
     *  @param _slot The slot to deposit money.
     * */
    function deposit(uint _slot) payable {
        Coffer coffer = coffers[msg.sender]; // unitialised storage variable? Why did they need to create a new coffer? Then whoever calls this function would be creating a new coffer everytime they call this function and depositing the ether in a new coffer. 
        coffer.slots[_slot] += msg.value; // 
    }
    
    /** @dev withdraw all of the money of  one's coffer slot.
     *  @param _slot The slot to withdraw money from.
     * */
       function withdraw(uint _slot) {
        Coffer coffer = coffers[msg.sender]; // Is this unitialized storage pointer? what happens if the msg.sender doesn't have a coffer?? ? 
        msg.sender.transfer(coffer.slots[_slot]);
        coffer.slots[_slot] = 0;
    }
}


