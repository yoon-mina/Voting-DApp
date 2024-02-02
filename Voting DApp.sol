// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Voting {
    address payable public owner; //컨트랙트의 소유자의 주소
    uint public totalVotes; //투표된 총 표수
    uint public registrationStartTime; //후보 등록이 시작되는 시간(UNIX 타임스탬프 형식)
    uint public votingStartTime; //투표가 시작되는 시간(UNIX 타임스탬프 형식)
    uint public winnerIndex; //승자 인덱스
    string public WinnerName; //승자 이름
    uint public winnerVotes; //승자 투표 수
    address public WinnerAddress; //승자 주소
    bool private whetherWithdraw; //컨트랙트의 소유자가 컨트랙트에서 이더를 인출했는지 여부
    uint public Nth; //현재 진행중인 투표의 회차

    struct Candidate { //후보자의 정보를 저장하는 구조체
        string name;
        uint votes;
        bool isRegistered;
    }

    //각각 주소에 따른 후보자 정보와 회차에 따른 승자 정보를 저장
    mapping (address => Candidate) public candidates;
    mapping (uint => Candidate) public NthWinner;
    
    //후보자들의 주소와 이름을 저장
    address[] public candidateAddresses;
    string[] public candidatesNames;
    
    //컨트랙트의 중요한 액션이 발생할 때마다 로그를 생성하여 블록체인에 저장
    event RegistrationStarted(uint startTime, uint endTime, uint Nth);
    event VotingStarted(uint startTime, uint endTime, uint Nth);
    event CandidateRegistered(string name);
    event VoteSubmitted(address voter, string candidateName, uint votes);
    event whoIsTheWinner(address WinnerAddress, string WinnerName, uint winnerVotes, uint Nth);
    event VotingClosed(uint Nth);

    //컨트랙트의 소유자를 설정
    constructor() {
        owner = payable(msg.sender);
    }

    //함수가 오직 컨트랙트의 소유자에 의해서만 호출될 수 있게함
    modifier onlyOwner() { 
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    //후보자 등록이 가능한 시간
    modifier duringRegistration() { 
        require(
            block.timestamp >= registrationStartTime &&
            block.timestamp < registrationStartTime + 1 minutes,
            "Registration isn't currently open"
        );
        _;
    }

    //투표가 가능한 시간
    modifier duringVoting() { 
        require(
            block.timestamp >= votingStartTime &&
            block.timestamp < votingStartTime + 1 minutes,
            "Voting isn't currently open"
        );
        _;
    }
    
    //투표 종료
    modifier isItClosed() { 
        require(registrationStartTime == 0 && votingStartTime == 0, "Voting has not yet been closed.");
        _;
    }
    
    // 투표 시스템 시작 
    function open() public onlyOwner isItClosed { 
        registrationStartTime = block.timestamp;
        votingStartTime = registrationStartTime + 1 minutes;
        Nth++;
        emit RegistrationStarted(registrationStartTime, registrationStartTime + 1 minutes, Nth);
        emit VotingStarted(votingStartTime, votingStartTime + 1 minutes, Nth);
    }

    // 주어진 문자열 배열(array) 내에 특정 문자열(_name)이 포함되어 있는지 확인
    function contains(string[] memory array, string memory _name) internal pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (keccak256(bytes(array[i])) == keccak256(bytes(_name))) {
                return true;
            }
        }
        return false;
    }
    
    //후보자 등록
    function registerCandidate(string memory _name) public payable duringRegistration {
        require(!candidates[msg.sender].isRegistered, "You've already registered as a candidate");
        require(!contains(candidatesNames, _name), "The name already exists");  
        candidates[msg.sender] = Candidate(_name, 0, true);
        candidateAddresses.push(msg.sender);
        candidatesNames.push(_name);
        emit CandidateRegistered(_name);
    }

    //현재 등록된 후보자의 이름 목록을 반환
    function getCandidates() public view returns(string[] memory) {
        return candidatesNames;
    }

    //자신이 지지하는 후보자에게 투표
    function vote(address candidate) public payable duringVoting {
        require(candidates[candidate].isRegistered, "Invalid candidate address");
        require(msg.value > 0, "Voting requires a non-zero amount of eth.");
        candidates[candidate].votes += msg.value;
        totalVotes += msg.value;
        
        emit VoteSubmitted(msg.sender, candidates[candidate].name, msg.value);
    }

    //후보자 결정
    function determineWinner() public onlyOwner {
        require(block.timestamp > votingStartTime + 1 minutes, "Voting is still open"); // 투표시간 지나야함.
        uint winningVoteCount = 0;

        for(uint i=0; i<candidateAddresses.length; i++) {
            if(candidates[candidateAddresses[i]].votes > winningVoteCount) {
                winningVoteCount = candidates[candidateAddresses[i]].votes;
                winnerIndex = i;
            }
        }
        WinnerAddress = candidateAddresses[winnerIndex];
        NthWinner[Nth] = candidates[WinnerAddress];
        WinnerName = NthWinner[Nth].name;
        winnerVotes = NthWinner[Nth].votes;
        emit whoIsTheWinner(WinnerAddress, WinnerName, winnerVotes, Nth);
    }

    // 승리한 후보자의 정보를 반환
    function getWinnerInfo() public view returns (Candidate memory) {
        return candidates[WinnerAddress];
    }

    //컨트랙트의 잔고를 컨트랙트 소유자에게 전송
    function withdraw() public onlyOwner {
        require(block.timestamp > votingStartTime, "Voting is still open");
        owner.transfer(address(this).balance);
        whetherWithdraw = true;
    }

    //모든 후보자 정보를 삭제하고, 투표 관련 변수를 초기화
    function close() public onlyOwner {
        require(whetherWithdraw, "You didn't withdraw.");
        for (uint i = 0; i < candidateAddresses.length; i++) {
            delete candidates[candidateAddresses[i]];
        }
        registrationStartTime = 0;
        votingStartTime = 0;    
        totalVotes = 0;
        winnerIndex = 0;
        WinnerName = "";
        candidatesNames = new string[](0);
        whetherWithdraw = false;
        winnerVotes = 0;
        WinnerAddress = 0x0000000000000000000000000000000000000000;
        emit VotingClosed(Nth);
    }
}
