// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SimpleDEX is Ownable, ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    
    // Fee del 0.3% (30 basis points)
    uint256 public constant FEE_PERCENT = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    // Eventos
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event PriceUpdated(address indexed token, uint256 price);
    
    // Errores personalizados
    error InsufficientAmount();
    error InsufficientLiquidity();
    error TransferFailed();
    error InvalidToken();
    error ZeroAmount();
    
    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Tokens must be different");
        
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }
    
    /**
     * @dev Añadir liquidez al pool
     * @param amountA Cantidad de TokenA a depositar
     * @param amountB Cantidad de TokenB a depositar
     */
    function addLiquidity(uint256 amountA, uint256 amountB) external onlyOwner nonReentrant {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();
        
        // Transferir tokens al contrato
        if (!tokenA.transferFrom(msg.sender, address(this), amountA)) revert TransferFailed();
        if (!tokenB.transferFrom(msg.sender, address(this), amountB)) revert TransferFailed();
        
        // Actualizar reservas
        reserveA += amountA;
        reserveB += amountB;
        
        emit LiquidityAdded(msg.sender, amountA, amountB);
    }
    
    /**
     * @dev Intercambiar TokenA por TokenB
     * @param amountAIn Cantidad de TokenA a intercambiar
     */
    function swapAforB(uint256 amountAIn) external nonReentrant {
        if (amountAIn == 0) revert ZeroAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
        
        // Calcular cantidad de salida usando la fórmula del producto constante
        // Aplicando fee: amountAIn_with_fee = amountAIn * (10000 - 30) / 10000
        uint256 amountAInWithFee = (amountAIn * (FEE_DENOMINATOR - FEE_PERCENT)) / FEE_DENOMINATOR;
        uint256 numerator = amountAInWithFee * reserveB;
        uint256 denominator = reserveA + amountAInWithFee;
        uint256 amountBOut = numerator / denominator;
        
        if (amountBOut == 0) revert InsufficientAmount();
        if (amountBOut >= reserveB) revert InsufficientLiquidity();
        
        // Transferir tokens
        if (!tokenA.transferFrom(msg.sender, address(this), amountAIn)) revert TransferFailed();
        if (!tokenB.transfer(msg.sender, amountBOut)) revert TransferFailed();
        
        // Actualizar reservas
        reserveA += amountAIn;
        reserveB -= amountBOut;
        
        emit TokensSwapped(msg.sender, address(tokenA), address(tokenB), amountAIn, amountBOut);
    }
    
    /**
     * @dev Intercambiar TokenB por TokenA
     * @param amountBIn Cantidad de TokenB a intercambiar
     */
    function swapBforA(uint256 amountBIn) external nonReentrant {
        if (amountBIn == 0) revert ZeroAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
        
        // Calcular cantidad de salida usando la fórmula del producto constante
        // Aplicando fee: amountBIn_with_fee = amountBIn * (10000 - 30) / 10000
        uint256 amountBInWithFee = (amountBIn * (FEE_DENOMINATOR - FEE_PERCENT)) / FEE_DENOMINATOR;
        uint256 numerator = amountBInWithFee * reserveA;
        uint256 denominator = reserveB + amountBInWithFee;
        uint256 amountAOut = numerator / denominator;
        
        if (amountAOut == 0) revert InsufficientAmount();
        if (amountAOut >= reserveA) revert InsufficientLiquidity();
        
        // Transferir tokens
        if (!tokenB.transferFrom(msg.sender, address(this), amountBIn)) revert TransferFailed();
        if (!tokenA.transfer(msg.sender, amountAOut)) revert TransferFailed();
        
        // Actualizar reservas
        reserveB += amountBIn;
        reserveA -= amountAOut;
        
        emit TokensSwapped(msg.sender, address(tokenB), address(tokenA), amountBIn, amountAOut);
    }
    
    /**
     * @dev Retirar liquidez del pool
     * @param amountA Cantidad de TokenA a retirar
     * @param amountB Cantidad de TokenB a retirar
     */
    function removeLiquidity(uint256 amountA, uint256 amountB) external onlyOwner nonReentrant {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();
        if (amountA > reserveA || amountB > reserveB) revert InsufficientLiquidity();
        
        // Transferir tokens de vuelta al owner
        if (!tokenA.transfer(msg.sender, amountA)) revert TransferFailed();
        if (!tokenB.transfer(msg.sender, amountB)) revert TransferFailed();
        
        // Actualizar reservas
        reserveA -= amountA;
        reserveB -= amountB;
        
        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }
    
    /**
     * @dev Obtener el precio de un token en términos del otro
     * @param _token Dirección del token del cual obtener el precio
     * @return price Precio del token (multiplicado por 1e18 para precisión)
     */
    function getPrice(address _token) external view returns (uint256 price) {
        if (reserveA == 0 || reserveB == 0) return 0;
        
        if (_token == address(tokenA)) {
            // Precio de TokenA en términos de TokenB
            price = (reserveB * 1e18) / reserveA;
        } else if (_token == address(tokenB)) {
            // Precio de TokenB en términos de TokenA
            price = (reserveA * 1e18) / reserveB;
        } else {
            revert InvalidToken();
        }
    }
    
    /**
     * @dev Calcular cuántos tokens de salida se obtendrán para una cantidad de entrada dada
     * @param tokenIn Dirección del token de entrada
     * @param amountIn Cantidad del token de entrada
     * @return amountOut Cantidad estimada del token de salida
     */
    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        if (reserveA == 0 || reserveB == 0) return 0;
        
        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - FEE_PERCENT)) / FEE_DENOMINATOR;
        
        if (tokenIn == address(tokenA)) {
            uint256 numerator = amountInWithFee * reserveB;
            uint256 denominator = reserveA + amountInWithFee;
            amountOut = numerator / denominator;
        } else if (tokenIn == address(tokenB)) {
            uint256 numerator = amountInWithFee * reserveA;
            uint256 denominator = reserveB + amountInWithFee;
            amountOut = numerator / denominator;
        } else {
            revert InvalidToken();
        }
    }
    
    /**
     * @dev Obtener las reservas actuales del pool
     * @return _reserveA Reserva actual de TokenA
     * @return _reserveB Reserva actual de TokenB
     */
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }
    
    /**
     * @dev Función de emergencia para retirar todos los tokens (solo owner)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        
        if (balanceA > 0) {
            tokenA.transfer(msg.sender, balanceA);
        }
        if (balanceB > 0) {
            tokenB.transfer(msg.sender, balanceB);
        }
        
        reserveA = 0;
        reserveB = 0;
    }
}