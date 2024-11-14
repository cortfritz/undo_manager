# UndoManager

a naive undo manager PoC for collaborative documents using Yex.

undo for collaborative documents has to support discrete operations for clients.  Think: 20 page document, client1 on first page, client2 on last page, client1 hits undo, what should happen?

This PoC experiments with a strategy of maintaining discrete state with separate documents and separate stacks of updates, and then managing the merge of non-undoer updates to facilitate discrete undo.

This is contra a strategy of maintining code that manutally inverts inserts, updates, etc which seems fraught, if maybe more efficient with memory.  

The theory is that undo state can be persisted generally, and called up and applied rapidly as most recent change only, one at atime.  Also Use of SVs might be more efficient than storing updates, but this is a simple naive PoC.

Next I'd like to experiment with Text to see if i can make that work.