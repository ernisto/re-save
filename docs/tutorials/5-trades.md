# Trading between players

```luau Any server
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})
```

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  version = 0,
}
players.buyer = {
  data = { coins = 80, items = {} },
  version = 0,
}
```

[Two players agree on a trade: the seller gives a sword,](mark:items = »{ 'sword' }) [and the buyer pays 50 coins.](mark:data = { »coins = 80) [They might not be on the same server, or online at all.](code:local players)

## Two updates

[Each side is one `resave.saveupdate`, which works on any key from any server.](code:local function trade)

```luau Any server
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})

local function trade(seller, buyer)
end
```

[The seller gives the sword and gets 50 coins,](code:players, seller)

```luau Any server
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})

local function trade(seller, buyer)
	resave.saveupdate(players, seller, function(data)
		table.remove(data.items, table.find(data.items, 'sword'))
		data.coins += 50
	end)
end
```

[and the buyer pays and gets the sword.](code:players, buyer)

```luau Any server
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})

local function trade(seller, buyer)
	resave.saveupdate(players, seller, function(data)
		table.remove(data.items, table.find(data.items, 'sword'))
		data.coins += 50
	end)
	resave.saveupdate(players, buyer, function(data)
		assert(data.coins >= 50, 'not enough coins')
		data.coins -= 50
		table.insert(data.items, 'sword')
	end)
end
```

[You try it with a buyer who can pay, and it works.](code:players.seller|players.buyer)

```cloud
players.seller = {
  data = { coins = 50, items = {} },
  version = 0,
}
players.buyer = {
  data = { coins = 30, items = { 'sword' } },
  version = 0,
}
```

## QA: "my sword vanished"

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  version = 0,
}
players.buyer = {
  data = { coins = 20, items = {} },
  version = 0,
}
```

[This time the buyer spent coins on another server a second before the trade, and has 20 left.](mark:data = { »coins = 20)

1. [The seller's update runs: the sword is removed, 50 coins are added, and it is written.](code:players, seller)

```cloud
players.seller = {
  data = { coins = 50, items = {} },
  version = 0,
}
players.buyer = {
  data = { coins = 20, items = {} },
  version = 0,
}
```

2. [The buyer's update runs on their real coins, and the `assert` fails.](mark:»data.coins >= 50 -> 20 >= 50) [Nothing is written for the buyer.](mark:data = { coins = 20, »items = {})

```output Output
not enough coins
```

[The seller was paid, the buyer got nothing, and the sword is gone.](code:players.seller|players.buyer) [Swap the order, and the buyer gets a free sword whenever the seller's side fails.](code:players, buyer) [A DataStore error on the second write does the same, with no `assert` involved.](code:players, seller|players, buyer)

## Why it broke

[A trade is **one decision**, but it was written as two independent saves.](code:players, seller|players, buyer) [Each one can succeed or fail alone, and nothing records whether the trade as a whole happened.](code:players.seller|players.buyer) [Checking first doesn't fix it: the buyer's coins can change between the check and the save.](mark:»data.coins >= 50) [Both keys have to follow one shared answer.](code:local function trade)

## One answer for both keys

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  version = 0,
}
players.buyer = {
  data = { coins = 20, items = {} },
  version = 0,
}
```

[`resave.savebatch` takes every update of the trade together,](code:resave.savebatch)

```luau Any server
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})

local function trade(seller, buyer)
	resave.savebatch(function(update)
		update(players, seller, function(data)
			table.remove(data.items, table.find(data.items, 'sword'))
			data.coins += 50
		end)
		update(players, buyer, function(data)
			assert(data.coins >= 50, 'not enough coins')
			data.coins -= 50
			table.insert(data.items, 'sword')
		end)
	end)
end
```

[and returns the first error.](code:return err)

```luau Any server
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})

local function trade(seller, buyer)
	local err = resave.savebatch(function(update)
		update(players, seller, function(data)
			table.remove(data.items, table.find(data.items, 'sword'))
			data.coins += 50
		end)
		update(players, buyer, function(data)
			assert(data.coins >= 50, 'not enough coins')
			data.coins -= 50
			table.insert(data.items, 'sword')
		end)
	end)
	return err
end
```

[Run the QA story again.](code:local function trade)

1. [Both updates are tested first, each on its key's current data. Nothing is written yet.](code:players, seller|players, buyer)
2. [The buyer's test fails, and the batch stops before touching either key.](mark:»data.coins >= 50 -> 20 >= 50)
3. [`resave.savebatch` returns the error,](mark:return »err -> '… not enough coins') [and neither save changed: the seller keeps the sword.](mark:items = »{ 'sword' })

## A trade that goes through

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  version = 0,
}
players.buyer = {
  data = { coins = 80, items = {} },
  version = 0,
}
```

[Now the buyer has 80 coins.](mark:data = { »coins = 80)

1. [Both tests pass.](code:players, seller|players, buyer)
2. [re-save writes a record for the trade, in a DataStore of its own: pending.](mark:state = »'pending')

```state tx store
tx1 = {
  state = 'pending',
  adopts = {
    ['players:seller'] = false,
    ['players:buyer'] = false,
  },
}
```

3. [Then it locks each key.](code:pendingtx)

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  pendingtx = {
    id = 'tx1',
    newdata = { coins = 50, items = {} },
  },
  version = 0,
}
players.buyer = {
  data = { coins = 80, items = {} },
  pendingtx = {
    id = 'tx1',
    newdata = { coins = 30, items = { 'sword' } },
  },
  version = 0,
}
```

[A locked save keeps its data as it was,](mark:data = »{ coins = 0, items = { 'sword' } }) [and holds the trade's result next to it, tagged with the trade's id.](mark:newdata = »{ coins = 50, items = {} }) [Each lock runs its update again on the newest data, so a change made since the test can still say no.](mark:»data.coins >= 50 -> 80 >= 50) [If a lock fails, the trade's record is deleted, and every key that was locked drops its lock and keeps its old data.](mark:id = »'tx1')

4. [With every key locked, one write flips the trade's record to committed.](mark:state = »'commited')

```state tx store
tx1 = {
  state = 'commited',
  adopts = {
    ['players:seller'] = false,
    ['players:buyer'] = false,
  },
}
```

**[That single write is the trade: before it nothing happened, after it everything did.](code:tx1 = {)**

5. [Each key then adopts its result: `newdata` becomes `data`, and the lock is gone.](code:players.seller|players.buyer)

```cloud
players.seller = {
  data = { coins = 50, items = {} },
  version = 0,
}
players.buyer = {
  data = { coins = 30, items = { 'sword' } },
  version = 0,
}
```

```state tx store
tx1 = {
  state = 'commited',
  adopts = {
    ['players:seller'] = true,
    ['players:buyer'] = true,
  },
}
```

6. [When every key has adopted, the trade's record is deleted.](code:no trade in progress)

```state tx store
-- no trade in progress
```

[`resave.savebatch` returns nil: the trade is committed.](mark:return »err -> nil)

## A crash in the middle

```cloud
players.seller = {
  data = { coins = 50, items = {} },
  version = 0,
}
players.buyer = {
  data = { coins = 80, items = {} },
  pendingtx = {
    id = 'tx1',
    newdata = { coins = 30, items = { 'sword' } },
  },
  version = 0,
}
```

```state tx store
tx1 = {
  state = 'commited',
  adopts = {
    ['players:seller'] = true,
    ['players:buyer'] = false,
  },
}
```

[The server running the trade dies right after the commit: the seller has adopted, the buyer is still locked.](code:players.buyer) [The buyer's save still shows 80 coins and no sword, but the answer is on record.](mark:state = »'commited')

[The next time any server loads or saves the buyer, it finds the lock, reads the trade's record, and adopts the result.](mark:data = »{ coins = 30, items = { 'sword' } })

```cloud
players.seller = {
  data = { coins = 50, items = {} },
  version = 0,
}
players.buyer = {
  data = { coins = 30, items = { 'sword' } },
  version = 0,
}
```

```state tx store
-- no trade in progress
```

[Had the server died before the commit, the record would still say pending, with both keys locked.](mark:state = »'pending')

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  pendingtx = {
    id = 'tx1',
    newdata = { coins = 50, items = {} },
  },
  version = 0,
}
players.buyer = {
  data = { coins = 80, items = {} },
  pendingtx = {
    id = 'tx1',
    newdata = { coins = 30, items = { 'sword' } },
  },
  version = 0,
}
```

```state tx store
tx1 = {
  state = 'pending',
  adopts = {
    ['players:seller'] = false,
    ['players:buyer'] = false,
  },
}
```

[A trade has 5 minutes to commit. After that, whoever meets a lock treats the trade as cancelled: the lock is dropped, and the old data stays.](code:players.seller|players.buyer)

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  version = 0,
}
players.buyer = {
  data = { coins = 80, items = {} },
  version = 0,
}
```

```state tx store
-- no trade in progress
```

[Either way, both keys end up on the same side of the trade.](mark:items = »{ 'sword' })

## While a key is locked

```cloud
players.seller = {
  data = { coins = 0, items = { 'sword' } },
  pendingtx = {
    id = 'tx1',
    newdata = { coins = 50, items = {} },
  },
  version = 0,
}
```

```state tx store
tx1 = {
  state = 'pending',
  adopts = {
    ['players:seller'] = false,
    ['players:buyer'] = false,
  },
}
```

[A player whose save is locked keeps playing, and their saves still go through.](code:pendingtx) [Say the seller earns 5 coins: the update is applied to both copies, so it survives whichever way the trade ends.](mark:newdata = »{ coins = 55, items = {} })

```cloud
players.seller = {
  data = { coins = 5, items = { 'sword' } },
  pendingtx = {
    id = 'tx1',
    newdata = { coins = 55, items = {} },
  },
  version = 0,
}
```

[Until the trade ends, anyone reading the save sees the data from before it.](mark:data = »{ coins = 5, items = { 'sword' } })

[A second trade is different: a key can be in one trade at a time, so `resave.savebatch` returns an error for it.](mark:return »err -> '… pending tx')

```output Output
[withfreetx] pending tx
```

[Try again a moment later, and don't let one player open two trades at once.](code:local function trade)

## Other ways it says no

```cloud
```

```state tx store
```

[Calling `update` twice for the same key in one batch throws: put all of one player's changes in a single update.](code:players, seller)

```output Output
already defined a tx for seller
```

[An error raised by the builder itself is thrown too, before anything is written.](code:resave.savebatch)

```output Output
```

[Everything else is returned: a failed test, a failed lock, a failed commit.](code:return err) [The updates follow every rule from chapter two: they are tested like queued updates, then run again at the lock.](code:players, seller|players, buyer)

[When a trader is tracked on this server, the trade goes through their session: its oplog is saved along with the lock, and `session.data` shows the result when `resave.savebatch` returns.](code:local function trade)

[All-or-nothing writes across keys are called **transactions**.](code:resave.savebatch)
