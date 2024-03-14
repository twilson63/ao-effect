ClaimEligible = {}
Claims = {}
CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"

BaseEndGame = endGame
BaseStartGamePeriod = startGamePeriod 

function startGamePeriod()
  print("handle claim eligible")
  -- add each address in claim eligible in not there
  for k,v in pairs(Waiting) do
    if Waiting[k] and not Utils.includes(k, ClaimEligible) then
      table.insert(ClaimEligible, k)
    end
  end
  BaseStartGamePeriod()
end

function endGame()
  -- handle claims here
  print("handle claims") 
  -- add each address in claim eligible in not there
  for k,v in pairs(Players) do
    if Utils.includes(k, ClaimEligible) and not Utils.includes(k, Claims) then
      --send claim for Quest 2
      Send({Target = CRED, Action = "Transfer", Quantity = "500000", Recipient = k, Data = "Quest 2 Claim" })
      table.insert(Claims, k)
    end
  end
  BaseEndGame()
end