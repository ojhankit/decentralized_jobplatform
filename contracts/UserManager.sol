// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title UserManager
 * @dev Enhanced with DID (Decentralized Identity) support for self-sovereign identity
 */
contract UserManager {
    
    struct User {
        address wallet;
        string profile_url; // hash
        string role;
        string did;  // ✅ NEW: Decentralized Identity identifier
        bool did_verified;  // ✅ NEW: Flag for verified DID
    }

    struct VerifiableCredential {
        uint credential_id;
        address holder;
        string credential_type;  // e.g., "SkillCertification", "CompletedJobs"
        string proof;  // ZKP or signature proof
        uint issued_at;
        uint expires_at;
        bool revoked;
    }

    // State variables
    mapping(address => User) public users;
    mapping(string => address) public did_to_wallet;  // ✅ NEW: DID registry
    mapping(address => uint[]) public user_credentials;  // ✅ NEW: VC management
    mapping(uint => VerifiableCredential) public credentials;
    
    uint public credential_count;
    address public did_issuer;  // ✅ NEW: Trusted issuer for credentials

    // Events
    event UserRegistered(address indexed user, string role, string did);
    event UserProfileUpdated(address indexed user, string new_profile_url);
    event DIDVerified(address indexed user, string did);  // ✅ NEW
    event CredentialIssued(uint indexed credential_id, address indexed holder, string credential_type);  // ✅ NEW
    event CredentialRevoked(uint indexed credential_id);  // ✅ NEW

    modifier onlyDIDIssuer() {
        require(msg.sender == did_issuer, "Only DID issuer can issue credentials");
        _;
    }

    constructor() {
        did_issuer = msg.sender;
    }

    // ✅ NEW: Set trusted DID issuer (e.g., third-party identity provider)
    function setDIDIssuer(address _issuer) external {
        require(msg.sender == did_issuer, "Only current issuer can change issuer");
        require(_issuer != address(0), "Invalid issuer address");
        did_issuer = _issuer;
    }

    /**
     * @dev Register user with DID
     * DID format: "did:ethr:0x123..." (Ethereum-based DID)
     */
    function registerUser(
        string memory _role,
        string memory _profile_url,
        string memory _did
    ) public {
        require(users[msg.sender].wallet == address(0), "Already registered");
        require(bytes(_did).length > 0, "DID cannot be empty");
        require(did_to_wallet[_did] == address(0), "DID already registered");
        require(
            keccak256(bytes(_role)) == keccak256(bytes("Freelancer")) ||
            keccak256(bytes(_role)) == keccak256(bytes("Employer")),
            "Invalid role"
        );

        users[msg.sender] = User({
            wallet: msg.sender,
            role: _role,
            profile_url: _profile_url,
            did: _did,
            did_verified: false  // ✅ NEW: Requires verification
        });

        did_to_wallet[_did] = msg.sender;

        emit UserRegistered(msg.sender, _role, _did);
    }

    /**
     * @dev Verify DID ownership (off-chain verification required)
     * In production, use DID resolution and cryptographic proof
     */
    function verifyDID(address _user) external onlyDIDIssuer {
        require(users[_user].wallet != address(0), "User not registered");
        require(!users[_user].did_verified, "DID already verified");

        users[_user].did_verified = true;
        emit DIDVerified(_user, users[_user].did);
    }

    /**
     * @dev Issue Verifiable Credential (VC) to user
     * Used for skills, completed jobs, reputation
     */
    function issueCredential(
        address _holder,
        string memory _credential_type,
        string memory _proof,
        uint _duration_days
    ) external onlyDIDIssuer {
        require(users[_holder].wallet != address(0), "User not registered");
        require(users[_holder].did_verified, "DID not verified");
        require(bytes(_credential_type).length > 0, "Credential type required");

        credential_count += 1;
        credentials[credential_count] = VerifiableCredential({
            credential_id: credential_count,
            holder: _holder,
            credential_type: _credential_type,
            proof: _proof,
            issued_at: block.timestamp,
            expires_at: block.timestamp + (_duration_days * 1 days),
            revoked: false
        });

        user_credentials[_holder].push(credential_count);
        emit CredentialIssued(credential_count, _holder, _credential_type);
    }

    /**
     * @dev Revoke a credential
     */
    function revokeCredential(uint _credential_id) external onlyDIDIssuer {
        require(credentials[_credential_id].credential_id != 0, "Credential not found");
        require(!credentials[_credential_id].revoked, "Already revoked");

        credentials[_credential_id].revoked = true;
        emit CredentialRevoked(_credential_id);
    }

    /**
     * @dev Get all credentials for a user
     */
    function getUserCredentials(address _user) external view returns (uint[] memory) {
        return user_credentials[_user];
    }

    /**
     * @dev Get credential details
     */
    function getCredential(uint _credential_id) external view returns (
        uint credential_id,
        address holder,
        string memory credential_type,
        uint issued_at,
        uint expires_at,
        bool valid
    ) {
        VerifiableCredential memory vc = credentials[_credential_id];
        bool isValid = !vc.revoked && block.timestamp <= vc.expires_at;
        return (
            vc.credential_id,
            vc.holder,
            vc.credential_type,
            vc.issued_at,
            vc.expires_at,
            isValid
        );
    }

    /**
     * @dev Verify if user has valid credential of type
     * Useful for JobManager to verify freelancer skills
     */
    function hasValidCredential(address _user, string memory _type) external view returns (bool) {
        uint[] memory creds = user_credentials[_user];
        for (uint i = 0; i < creds.length; i++) {
            VerifiableCredential memory vc = credentials[creds[i]];
            if (
                keccak256(bytes(vc.credential_type)) == keccak256(bytes(_type)) &&
                !vc.revoked &&
                block.timestamp <= vc.expires_at
            ) {
                return true;
            }
        }
        return false;
    }

    // ✅ UPDATED: Original functions with DID support
    function updateProfile(string memory _new_profile_url) public {
        require(users[msg.sender].wallet != address(0), "User not registered");
        users[msg.sender].profile_url = _new_profile_url;
        emit UserProfileUpdated(msg.sender, _new_profile_url);
    }

    function getUser(address _user) public view returns (User memory) {
        return users[_user];
    }

    /**
     * @dev NEW: Resolve DID to wallet address
     */
    function resolveDID(string memory _did) external view returns (address) {
        return did_to_wallet[_did];
    }
}