using Microsoft.Diagnostics.Tracing;
using Microsoft.Diagnostics.Tracing.Session;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace TraceListener
{
    class DelphiTestEvents
    {
        TraceEventSession session;
        int EventCounter;

        public event EventHandler<TestEventData> OnEvent;
        public event EventHandler<string> OnEventAny;

        public void Start()
        {
            if (session == null)
            {
                SetupSession();
            }
        }

        public void Stop()
        {
            if (session != null)
            {
                session.Dispose();
            }
        }

        private void SetupSession()
        {
            session = new TraceEventSession("DelphiTestProvider");

            // ETW buffers events and only delivers them after buffering up for some amount of time.  Thus 
            // there is a small delay of about 2-4 seconds between the timestamp on the event (which is very 
            // accurate), and the time we actually get the event.
            session.Source.Dynamic.All += delegate (TraceEvent data)
            {
                Interlocked.Increment(ref EventCounter);
                var str = data.ToString();
                Debug.WriteLine(string.Format("GOT Event {0} ", str));

                OnEventAny?.Invoke(this, data.ToString());
            };

            session.Source.Dynamic.AddCallbackForProviderEvent("Delphi-Test-Provider", "Test/Random", delegate (TraceEvent data)
            {
                var index = Interlocked.Increment(ref EventCounter);

                try
                {
                    var obj = new TestEventData(index, data);
                    Debug.WriteLine(obj);
                    OnEvent?.Invoke(this, obj);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("Exception while parsing event: " + ex);
                }

            });

            session.Source.UnhandledEvents += delegate (TraceEvent data)
            {
                if ((int)data.ID != 0xFFFE)         // The EventSource manifest events show up as unhanded, filter them out.
                    Debug.WriteLine("GOT UNHANDLED EVENT: " + data.Dump());
            };

            var traceOptions = new TraceEventProviderOptions
            {
                StacksEnabled = false
            };

            session.EnableProvider("Delphi-Test-Provider", options: traceOptions);

            // go into a loop processing events can calling the callbacks.  Because this is live data (not from a file)
            // processing never completes by itself, but only because someone called 'source.Dispose()'.  
            Task.Run(() =>
            {
                session.Source.Process();
            });
        }
    }


    class TestEventData
    {
        public int Index { get; }

        public string StringValue { get; }
        public int IntValue { get; }

        public TestEventData(int eventIndex, TraceEvent traceEvent)
        {
            Index = eventIndex;

            StringValue = (string)traceEvent.PayloadByName("StringValue");
            IntValue = (int)traceEvent.PayloadByName("IntValue");
        }

        public override string ToString()
        {
            return $"TestEvent {Index}: {StringValue} - {IntValue}";
        }
    }
}
