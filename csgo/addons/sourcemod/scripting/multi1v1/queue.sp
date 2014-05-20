/**
 * Initializes the queue. The handle returned by this must be closed or destroyed later.
 */
public Handle:Queue_Init() {
	new Handle:queueHandle = CreateArray();
	ClearArray(queueHandle);
	return queueHandle;
}

/**
 * Push a Client into the Queue (don't add a client if already in queue).
 */
public Queue_Enqueue(Handle:queueHandle, any:client) {
	if (Queue_Find(queueHandle, client) == -1)
		PushArrayCell(queueHandle, client);
}

/**
 * Finds a client in the Queue and returns their index.
 */
public any:Queue_Find(Handle:queueHandle, any:client) {
	return FindValueInArray(queueHandle, client);
}

/**
 * Drops a client from the Queue.
 */
public Queue_Drop(Handle:queueHandle, any:client) {
	new index = Queue_Find(queueHandle, client);
	if (index != -1)
		RemoveFromArray(queueHandle, index);
}

/**
 * Get queue length, does not validate clients in queue.
 */
public any:Queue_Length(Handle:queueHandle) {
	return GetArraySize(queueHandle);
}

/**
 * Test if queue is empty.
 */
public bool:Queue_IsEmpty(Handle:queueHandle) {
	return Queue_Length(queueHandle) == 0;
}

/**
 * Peeks the head of the queue.
 */
public any:Queue_Peek(Handle:queueHandle) {
	if (Queue_IsEmpty(queueHandle))
		return -1;
	return GetArrayCell(queueHandle, 0);
}

/**
 * Fetch next client from queue.
 */
public any:Queue_Dequeue(Handle:queueHandle) {
	if (Queue_IsEmpty(queueHandle))
		return -1;
	new val = Queue_Peek(queueHandle);
	RemoveFromArray(queueHandle, 0);
	return val;
}

/**
 * Frees the handle used by the queue.
 */
public Queue_Destroy(Handle:queueHandle) {
	CloseHandle(queueHandle);
}