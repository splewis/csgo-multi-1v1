/**
 * This code is largely thanks to Lordearon on the AlliedModders forum.
 */

// TODO: this entire structure can probably be done more simply with a ADT array

#pragma semicolon 1
#include <sourcemod>

new g_QueueSize = MAXPLAYERS+1;
new g_ClientQueue[MAXPLAYERS+1];
new g_QueueHead = 0;
new g_QueueTail = 0;
new g_isWaiting[MAXPLAYERS+1] = false;

public InitQueue() {
	g_QueueHead = 0;
	g_QueueTail = 0;
}

/**
 * Push a Client into the Queue (don't add a client if already in queue)
 */
public EnQueue(client) {
	if (FindInQueue(client) != -1)
		return -1;

	g_ClientQueue[g_QueueTail] = client;
	g_QueueTail = (g_QueueTail + 1) % g_QueueSize;
	return 0;
}

/**
 * Finds a client in the Queue
 */
public FindInQueue(client) {
	new i = g_QueueHead;
	new bool:found = false;

	while (i != g_QueueTail && !found) {
		if (client == g_ClientQueue[i]) {
			found = true;
		} else {
			i = (i + 1) % g_QueueSize;
		}
	}
	return found ? i : -1;
}

/**
 * Drops a client from the Queue
 */
public DropFromQueue(client) {
	// find client cur position in queue
	new cur = FindInQueue(client);

	if (cur == -1) {
		return -1;
	} else if (cur == g_QueueHead) {
		g_QueueHead = (cur + 1) % g_QueueSize;
	} else {
		// shift all clients forward in queue
		new next, prev = cur == 0 ? g_QueueSize : cur - 1;
		while (cur != g_QueueTail) {
			next = (cur + 1) % g_QueueSize;
			if (next != g_QueueTail) {
				// move next client forward to cur
				g_ClientQueue[cur] = g_ClientQueue[next];
			}
			prev = cur;
			cur = next;
		}
		// tail needs to update as well
		g_QueueTail = prev;
	}
	return 0;
}

/**
 * Get queue length, does not validate clients in queue
 */
public GetQueueLength() {
	new i = g_QueueHead, count = 0;
	while (i != g_QueueTail) {
		count++;
		i = (i + 1) % g_QueueSize;
	}
	return count;
}

/**
 * Test if queue is empty
*/
public IsQueueEmpty() {
	return g_QueueTail == g_QueueHead;
}

/**
 * Fetch next client from queue
 */
public DeQueue() {
	// check if queue is empty
	if (g_QueueTail == g_QueueHead)
		return -1;

	// head advances on dequeue
	new client = g_ClientQueue[g_QueueHead];
	g_QueueHead = (g_QueueHead + 1) % g_QueueSize;
	return client;
}
