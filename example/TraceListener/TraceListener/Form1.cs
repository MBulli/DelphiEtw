using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace TraceListener
{
    public partial class Form1 : Form
    {
        DelphiTestEvents events;

        public Form1()
        {
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            events = new DelphiTestEvents();
            events.OnEvent += Events_OnEvent;
            events.OnEventAny += Events_OnEventAny;
            events.Start();
        }

        private void Events_OnEventAny(object sender, string e)
        {
            MethodInvoker methodInvokerDelegate = delegate () {
                textBox1.AppendText(e + Environment.NewLine);
            };

            Invoke(methodInvokerDelegate);
        }

        private void Events_OnEvent(object sender, TestEventData e)
        {
            MethodInvoker methodInvokerDelegate = delegate () {
                textBox1.AppendText(e.ToString() + "\n");
            };

            Invoke(methodInvokerDelegate);
        }
    }
}
