/**
 * Initializes the queue. The handle returned by this must be closed or destroyed later.
 */
public Handle Queue_Init() {
	new Handle:queueHandle = CreateArray();
	ClearArray(queueHandle);
	return queueHandle;
}

/**
 * Push a Client into the Queue (don't add a client if already in queue).
 */
public void Queue_Enqueue(Handle queueHandle, int client) {
	if (Queue_Find(queueHandle, client) == -1)
		PushArrayCell(queueHandle, client);
}

/**
 * Finds a client in the Queue and returns their index, or -1 if not found.
 */
public int Queue_Find(Handle queueHandle, int client) {
	return FindValueInArray(queueHandle, client);
}

/**
 * Returns if a player is inside the queue.
 */
public bool Queue_Inside(Handle queueHandle, int client) {
	return Queue_Find(queueHandle, client) >= 0;
}

/**
 * Drops a client from the Queue.
 */
public void Queue_Drop(Handle queueHandle, int client) {
	int index = Queue_Find(queueHandle, client);
	if (index != -1)
		RemoveFromArray(queueHandle, index);
}

/**
 * Get queue length, does not validate clients in queue.
 */
public int Queue_Length(Handle queueHandle) {
	return GetArraySize(queueHandle);
}

/**
 * Test if queue is empty.
 */
public bool Queue_IsEmpty(Handle queueHandle) {
	return Queue_Length(queueHandle) == 0;
}

/**
 * Peeks the head of the queue.
 */
public int Queue_Peek(Handle queueHandle) {
	if (Queue_IsEmpty(queueHandle))
		return -1;
	return GetArrayCell(queueHandle, 0);
}

/**
 * Fetch next client from queue.
 */
public int Queue_Dequeue(Handle queueHandle) {
	if (Queue_IsEmpty(queueHandle))
		return -1;
	int val = Queue_Peek(queueHandle);
	RemoveFromArray(queueHandle, 0);
	return val;
}

/**
 * Clears all entires in a queue.
 */
public void Queue_Clear(Handle queueHandle) {
	ClearArray(queueHandle);
}

/**
 * Frees the handle used by the queue.
 */
public void Queue_Destroy(Handle queueHandle) {
	CloseHandle(queueHandle);
}