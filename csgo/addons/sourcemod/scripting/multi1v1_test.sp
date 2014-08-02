#pragma semicolon 1
#include <sourcemod>
#include <testing>


/** multi1v1 function includes **/
#include "multi1v1/generic.sp"
#include "multi1v1/queue.sp"


public Plugin:myinfo = {
    name = "[Multi1v1] Test plugin",
    author = "splewis",
    description = "Multi-arena 1v1 laddering",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    QueueTest();
}

public QueueTest() {
    SetTestContext("QueueTest");
    new Handle:q = Queue_Init();
    AssertEq("Queue length 0 on init", Queue_Length(q), 0);
    AssertTrue("Queue empty on init", Queue_IsEmpty(q));

    Queue_Enqueue(q, 5);
    Queue_Enqueue(q, 7);
    Queue_Enqueue(q, 3);

    AssertFalse("Queue not empty on init", Queue_IsEmpty(q));
    AssertEq("Queue length 3 after inserts", Queue_Length(q), 3);

    AssertEq("Got index of 7", Queue_Find(q, 7), 1);
    AssertEq("Got index of 10", Queue_Find(q, 10), -1);

    AssertEq("Peek got 5", Queue_Peek(q), 5);

    AssertTrue("5 in the queue", Queue_Inside(q, 5));
    AssertTrue("7 in the queue", Queue_Inside(q, 7));
    AssertTrue("3 in the queue", Queue_Inside(q, 3));

    AssertEq("5 dequeued", Queue_Dequeue(q), 5);
    AssertEq("7 dequeued", Queue_Dequeue(q), 7);
    AssertEq("3 dequeued", Queue_Dequeue(q), 3);

    AssertEq("Queue length 0 when empty", Queue_Length(q), 0);

    Queue_Destroy(q);
}
