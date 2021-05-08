import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";


import "./IZapper.sol";
import "../common/IPancakePair.sol";
import "../common/IPancakeRouter02.sol";

contract Zapper is Ownable, IZapper {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    /*  ====================
            CONSTANTS
        =====================
     */

    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    IPancakeRouter02 private constant ROUTER = IPancakeRouter02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);

    /*  ====================
           STATE VARIABLES
        =====================
    */

    mapping(address => address) private routePairAddresses;


    /*  ====================
                INIT
        ====================
     */

    constructor () public {}

    receive() external payable {}


    /*  ====================
           VIEW FUNCTIONS
        ====================
    */

    function routePair(address _address) external view returns (address) {
        return routePairAddresses[_address];
    }


    /*  =========================
           EXTERNAL FUNCTIONS
        =========================
     */

    function zapBNBToLP(address _to) external payable {
        _swapBNBToLP(_to, msg.value, msg.sender);
    }


    function zapTokenToLP(address _from, uint amount, address _to) external {
        require(_from != WBNB, "use zapBNBToLP when BNB is input");

        IBEP20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from);

        IPancakePair pair = IPancakePair(_to);
        address token0 = pair.token0();
        address token1 = pair.token1();

        // BTS, BTD, BUSD to create BTS-BUSD or BTD-BUSD will hit this if
        if (_from == token0 || _from == token1) {
            // swap half amount for other
            address other = _from == token0 ? token1 : token0;
            _approveTokenIfNeeded(other);
            uint sellAmount = amount.div(2);
            uint otherAmount = _swap(_from, sellAmount, other, address(this));
            ROUTER.addLiquidity(_from, other, amount.sub(sellAmount), otherAmount, 0, 0, msg.sender, block.timestamp);
        } else {

            // Unknown future input tokens will make use of this
            uint bnbAmount = _swapTokenForBNB(_from, amount, address(this));
            _swapBNBToLP(_to, bnbAmount, msg.sender);
        }
    }

    function breakLP(address _from, uint amount) external {
        IBEP20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from);

        IPancakePair pair = IPancakePair(_from);
        address token0 = pair.token0();
        address token1 = pair.token1();
        if (token0 == WBNB || token1 == WBNB) {
            ROUTER.removeLiquidityETH(token0 != WBNB ? token0 : token1, amount, 0, 0, msg.sender, block.timestamp);
        } else {
            ROUTER.removeLiquidity(token0, token1, amount, 0, 0, msg.sender, block.timestamp);
        }

    }


    /*  =========================
           PRIVATE FUNCTIONS
        =========================
     */

    function _approveTokenIfNeeded(address token) private {
        if (IBEP20(token).allowance(address(this), address(ROUTER)) == 0) {
            IBEP20(token).safeApprove(address(ROUTER), uint(~0));
        }
    }

    function _swapBNBToLP(address lp, uint amount, address receiver) private {
        {
            IPancakePair pair = IPancakePair(lp);
            address token0 = pair.token0();
            address token1 = pair.token1();
            if (token0 == WBNB || token1 == WBNB) {
                address token = token0 == WBNB ? token1 : token0;
                uint swapValue = amount.div(2);
                uint tokenAmount = _swapBNBForToken(token, swapValue, address(this));

                _approveTokenIfNeeded(token);
                ROUTER.addLiquidityETH{value : amount.sub(swapValue)}(token, tokenAmount, 0, 0, receiver, block.timestamp);
            } else {
                uint swapValue = amount.div(2);
                uint token0Amount = _swapBNBForToken(token0, swapValue, address(this));
                uint token1Amount = _swapBNBForToken(token1, amount.sub(swapValue), address(this));

                _approveTokenIfNeeded(token0);
                _approveTokenIfNeeded(token1);
                ROUTER.addLiquidity(token0, token1, token0Amount, token1Amount, 0, 0, receiver, block.timestamp);
            }
        }
    }

    function _swapBNBForToken(address token, uint value, address receiver) private returns (uint) {
        address[] memory path;

        if (routePairAddresses[token] != address(0)) {
            //Eg [WBNB, BUSD, BTS/BTD]
            path = new address[](3);
            path[0] = WBNB;
            path[1] = routePairAddresses[token];
            path[2] = token;
        } else {
            path = new address[](2);
            path[0] = WBNB;
            path[1] = token;
        }

        uint[] memory amounts = ROUTER.swapExactETHForTokens{value : value}(0, path, receiver, block.timestamp);
        return amounts[amounts.length - 1];
    }

    function _swapTokenForBNB(address token, uint amount, address receiver) private returns (uint) {
        address[] memory path;
        if (routePairAddresses[token] != address(0)) {
            //Eg [BTD/BTS, BUSD, WBNB]
            path = new address[](3);
            path[0] = token;
            path[1] = routePairAddresses[token];
            path[2] = WBNB;
        } else {
            path = new address[](2);
            path[0] = token;
            path[1] = WBNB;
        }

        uint[] memory amounts = ROUTER.swapExactTokensForETH(amount, 0, path, receiver, block.timestamp);
        return amounts[amounts.length - 1];
    }

    /**
        Generic swap function that can swap between any two tokens with a maximum of three intermediate hops
        Not very useful for our current use case as bolt input currencies will only be BUSD, WBNB, BTD, BTS
        However having this function helps us open up to more input currencies
    **/

    function _swap(address _from, uint amount, address _to, address receiver) private returns (uint) {
        address intermediate = routePairAddresses[_from];
        if (intermediate == address(0)) {
            intermediate = routePairAddresses[_to];
        }

        address[] memory path;
        if (intermediate != address(0) && (_from == WBNB || _to == WBNB)) {
            // Eg [WBNB, BUSD, BTS/BTD] or [BTS/BTD, BUSD, WBNB]
            path = new address[](3);
            path[0] = _from;
            path[1] = intermediate;
            path[2] = _to;
        } else if (intermediate != address(0) && (_from == intermediate || _to == intermediate)) {
            // Eg [BUSD, BTS/BTD] or [BTS/BTD, BUSD]
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else if (intermediate != address(0) && routePairAddresses[_from] == routePairAddresses[_to]) {
            // Eg [BTD, BUSD, BTS] or [BTS, BUSD, BTD]
            path = new address[](3);
            path[0] = _from;
            path[1] = intermediate;
            path[2] = _to;
        } else if (routePairAddresses[_from] != address(0) && routePairAddresses[_to] != address(0) && routePairAddresses[_from] != routePairAddresses[_to]) {
            // Eg routePairAddresses[xToken] = xRoute
            // [BTS/BTS, BUSD, WBNB, xRoute, xToken]
            path = new address[](5);
            path[0] = _from;
            path[1] = routePairAddresses[_from];
            path[2] = WBNB;
            path[3] = routePairAddresses[_to];
            path[4] = _to;
        } else if (intermediate != address(0) && routePairAddresses[_from] != address(0)) {
            // Eg [BTS/BTD, BUSD, WBNB, xTokenWithWBNBLiquidity]
            path = new address[](4);
            path[0] = _from;
            path[1] = intermediate;
            path[2] = WBNB;
            path[3] = _to;
        } else if (intermediate != address(0) && routePairAddresses[_to] != address(0)) {
            // Eg [xTokenWithWBNBLiquidity, WBNB, BUSD, BTS/BTD]
            path = new address[](4);
            path[0] = _from;
            path[1] = WBNB;
            path[2] = intermediate;
            path[3] = _to;
        } else if (_from == WBNB || _to == WBNB) {
            // Eg [WBNB, xTokenWithWBNBLiquidity] or [xTokenWithWBNBLiquidity, WBNB]
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            // Eg [xTokenWithWBNBLiquidity, WBNB, yTokenWithWBNBLiquidity]
            path = new address[](3);
            path[0] = _from;
            path[1] = WBNB;
            path[2] = _to;
        }

        uint[] memory amounts = ROUTER.swapExactTokensForTokens(amount, 0, path, receiver, block.timestamp);
        return amounts[amounts.length - 1];
    }

    /* ========================
            OWNER FUNCTIONS
       ========================
   */

    /*
         Helps store intermediate route information to convert a token to WBNB
    */
    function setRoutePairAddress(address asset, address route) external onlyOwner {
        routePairAddresses[asset] = route;
    }


    /*
         Withdraws tokens belonging to the contract
    */
    function withdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }

        IBEP20(token).transfer(owner(), IBEP20(token).balanceOf(address(this)));
    }
}