using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Security.Principal;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace Apex4MiniGui
{
    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            if (!IsAdministrator())
            {
                try
                {
                    Process.Start(new ProcessStartInfo(Application.ExecutablePath)
                    {
                        UseShellExecute = true,
                        Verb = "runas",
                        Arguments = string.Join(" ", args.Select(a => "\"" + a.Replace("\"", "\\\"") + "\"")),
                        WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory
                    });
                }
                catch { }
                return;
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm(args.Any(a => string.Equals(a, "--start", StringComparison.OrdinalIgnoreCase))));
        }

        private static bool IsAdministrator()
        {
            using (var identity = WindowsIdentity.GetCurrent())
                return new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
        }
    }

    internal sealed class MainForm : Form
    {
        private readonly string root = AppDomain.CurrentDomain.BaseDirectory;
        private readonly Button startButton = new Button();
        private readonly Button stopButton = new Button();
        private readonly TrackBar triggerSlider = new TrackBar();
        private readonly TrackBar rumbleSlider = new TrackBar();
        private readonly Label triggerValue = new Label();
        private readonly Label rumbleValue = new Label();
        private readonly Label status = new Label();
        private readonly NotifyIcon tray = new NotifyIcon();
        private readonly object stateLock = new object();
        private Process bridge;
        private HidHideSession hidHide;
        private bool exiting;

        public MainForm(bool autoStart)
        {
            Text = "APEX4 DualSense Bridge";
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            ClientSize = new Size(470, 405);
            MinimumSize = MaximumSize = Size;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.FromArgb(17, 24, 39);
            ForeColor = Color.White;
            Font = new Font("Microsoft YaHei UI", 9F);

            AddLabel("APEX4 DualSense Bridge", 24, 20, 420, 34, 19F, FontStyle.Bold);
            AddLabel("隐藏实体 Xbox · 虚拟 DualSense · 扳机 · 振动", 25, 58, 420, 24, 9F, FontStyle.Regular, Color.FromArgb(156, 163, 175));

            status.SetBounds(24, 94, 422, 46);
            status.TextAlign = ContentAlignment.MiddleLeft;
            status.Padding = new Padding(14, 0, 0, 0);
            status.BackColor = Color.FromArgb(31, 41, 55);
            status.Text = "●  已停止，HidHide 已还原";
            Controls.Add(status);

            AddLabel("自适应扳机强度", 24, 157, 240, 24, 10F, FontStyle.Regular);
            ConfigureSlider(triggerSlider, 24, 181);
            ConfigureValue(triggerValue, 374, 157);
            AddLabel("振动强度", 24, 231, 240, 24, 10F, FontStyle.Regular);
            ConfigureSlider(rumbleSlider, 24, 255);
            ConfigureValue(rumbleValue, 374, 231);

            var settings = MiniSettings.Load(Path.Combine(root, "APEX4-Mini.settings"));
            triggerSlider.Value = settings.Trigger;
            rumbleSlider.Value = settings.Rumble;
            UpdateValues();
            triggerSlider.ValueChanged += delegate { UpdateValues(); };
            rumbleSlider.ValueChanged += delegate { UpdateValues(); };

            ConfigureButton(startButton, "启动", 24, 319, 120, Color.FromArgb(37, 99, 235));
            ConfigureButton(stopButton, "停止", 154, 319, 120, Color.FromArgb(220, 38, 38));
            var hideButton = new Button();
            ConfigureButton(hideButton, "最小化到托盘", 284, 319, 162, Color.FromArgb(55, 65, 81));
            startButton.Click += async delegate { await StartBridgeAsync(); };
            stopButton.Click += async delegate { await StopBridgeAsync(); };
            hideButton.Click += delegate { Hide(); };
            stopButton.Enabled = false;

            AddLabel("停止或从托盘退出时，会自动停止马达并恢复 HidHide 原配置。", 24, 369, 422, 22, 8.5F, FontStyle.Regular, Color.FromArgb(156, 163, 175));
            InitializeTray();
            Resize += delegate { if (WindowState == FormWindowState.Minimized) Hide(); };
            FormClosing += OnFormClosing;
            if (autoStart) Shown += async delegate { await StartBridgeAsync(); };
        }

        private Label AddLabel(string text, int x, int y, int w, int h, float size, FontStyle style, Color? color = null)
        {
            var label = new Label { Text = text, ForeColor = color ?? ForeColor, Font = new Font(Font.FontFamily, size, style) };
            label.SetBounds(x, y, w, h);
            Controls.Add(label);
            return label;
        }

        private void ConfigureSlider(TrackBar slider, int x, int y)
        {
            slider.SetBounds(x, y, 422, 42);
            slider.Minimum = 0; slider.Maximum = 200; slider.TickFrequency = 10;
            Controls.Add(slider);
        }

        private void ConfigureValue(Label label, int x, int y)
        {
            label.SetBounds(x, y, 72, 24); label.TextAlign = ContentAlignment.TopRight;
            label.ForeColor = Color.FromArgb(96, 165, 250); Controls.Add(label);
        }

        private void ConfigureButton(Button button, string text, int x, int y, int w, Color color)
        {
            button.Text = text; button.SetBounds(x, y, w, 38); button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 0; button.BackColor = color; button.ForeColor = Color.White;
            Controls.Add(button);
        }

        private void InitializeTray()
        {
            tray.Icon = Icon; tray.Text = "APEX4 DualSense Bridge"; tray.Visible = true;
            var menu = new ContextMenuStrip();
            menu.Items.Add("打开界面", null, delegate { ShowWindow(); });
            menu.Items.Add("启动", null, async delegate { await StartBridgeAsync(); });
            menu.Items.Add("停止并还原 HidHide", null, async delegate { await StopBridgeAsync(); });
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("退出", null, async delegate { await ExitAsync(); });
            tray.ContextMenuStrip = menu;
            tray.DoubleClick += delegate { ShowWindow(); };
        }

        private void ShowWindow()
        {
            Show(); WindowState = FormWindowState.Normal; Activate();
        }

        private Task StartBridgeAsync()
        {
            lock (stateLock) { if (bridge != null) return Task.FromResult(0); }
            var engine = Path.Combine(root, "ApexSenseBridge.exe");
            if (!File.Exists(engine)) { MessageBox.Show("缺少 ApexSenseBridge.exe。", Text); return Task.FromResult(0); }
            try
            {
                SetState(true, "●  正在配置 HidHide…");
                SaveSettings();
                hidHide = new HidHideSession(root, engine);
                hidHide.Activate();
                var args = string.Format("bridge-triggers --space-station --xinput-index 0 --virtual-backend integrated --trigger-strength {0} --rumble-strength {1}", triggerSlider.Value, rumbleSlider.Value);
                var process = new Process { StartInfo = new ProcessStartInfo(engine, args) {
                    WorkingDirectory = root, UseShellExecute = false, CreateNoWindow = true,
                    RedirectStandardOutput = true, RedirectStandardError = true } };
                process.EnableRaisingEvents = true;
                process.OutputDataReceived += delegate(object s, DataReceivedEventArgs e) { if (e.Data != null && e.Data.Contains("Bridge running")) SafeUi(delegate { SetState(true, "●  运行中：Xbox 360 已隐藏"); }); };
                process.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) { if (e.Data != null) AppendLog(e.Data); };
                process.Exited += async delegate { await OnBridgeExitedAsync(process); };
                lock (stateLock) { bridge = process; }
                if (!process.Start()) throw new InvalidOperationException("无法启动 Bridge。");
                process.BeginOutputReadLine(); process.BeginErrorReadLine();
            }
            catch (Exception ex)
            {
                lock (stateLock) { bridge = null; }
                RestoreHidHideAsync().Wait();
                SetState(false, "●  启动失败，HidHide 已还原");
                MessageBox.Show(ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            return Task.FromResult(0);
        }

        private async Task StopBridgeAsync()
        {
            Process current;
            lock (stateLock) { current = bridge; }
            if (current == null) { await RestoreHidHideAsync(); SetState(false, "●  已停止，HidHide 已还原"); return; }
            SetState(true, "●  正在停止并还原 HidHide…");
            try
            {
                var engine = Path.Combine(root, "ApexSenseBridge.exe");
                using (var stopper = Process.Start(new ProcessStartInfo(engine, "stop-active-sessions") { UseShellExecute = false, CreateNoWindow = true }))
                    if (stopper != null) stopper.WaitForExit(5000);
                await Task.Run(delegate { if (!current.WaitForExit(12000)) current.Kill(); });
            }
            catch { try { current.Kill(); } catch { } }
            await RestoreHidHideAsync();
            SetState(false, "●  已停止，HidHide 已还原");
        }

        private async Task OnBridgeExitedAsync(Process process)
        {
            lock (stateLock) { if (ReferenceEquals(bridge, process)) bridge = null; }
            await RestoreHidHideAsync();
            SafeUi(delegate { SetState(false, "●  已停止，HidHide 已还原"); });
            process.Dispose();
        }

        private Task RestoreHidHideAsync()
        {
            HidHideSession session;
            lock (stateLock) { session = hidHide; hidHide = null; }
            return Task.Run(delegate { if (session != null) { try { session.Restore(); } catch (Exception ex) { AppendLog("HidHide restore failed: " + ex); } } });
        }

        private void SetState(bool running, string text)
        {
            status.Text = text; status.ForeColor = running ? Color.FromArgb(74, 222, 128) : Color.White;
            startButton.Enabled = !running; stopButton.Enabled = running;
            triggerSlider.Enabled = !running; rumbleSlider.Enabled = !running;
        }

        private void UpdateValues() { triggerValue.Text = triggerSlider.Value + "%"; rumbleValue.Text = rumbleSlider.Value + "%"; }
        private void SaveSettings() { MiniSettings.Save(Path.Combine(root, "APEX4-Mini.settings"), triggerSlider.Value, rumbleSlider.Value); }
        private void AppendLog(string line) { try { File.AppendAllText(Path.Combine(root, "APEX4-Mini.log"), DateTime.Now.ToString("s") + " " + line + Environment.NewLine); } catch { } }
        private void SafeUi(Action action) { try { if (!IsDisposed) BeginInvoke(action); } catch { } }

        private void OnFormClosing(object sender, FormClosingEventArgs e)
        {
            if (!exiting && e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); }
            else if (!exiting)
            {
                exiting = true;
                try { StopBridgeAsync().GetAwaiter().GetResult(); } catch { }
                tray.Visible = false;
                tray.Dispose();
            }
        }

        private async Task ExitAsync()
        {
            exiting = true; await StopBridgeAsync(); SaveSettings(); tray.Visible = false; tray.Dispose(); Close();
        }
    }

    internal sealed class HidHideSession
    {
        private readonly string cli;
        private readonly string bridge;
        private readonly List<string> addedApps = new List<string>();
        private readonly List<string> addedDevices = new List<string>();
        private HashSet<string> originalApps;
        private HashSet<string> originalDevices;
        private bool originalCloak;
        private bool originalInverse;
        private bool restored;

        public HidHideSession(string root, string bridge)
        {
            this.bridge = bridge;
            cli = new[] {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Nefarius Software Solutions", "HidHide", "x64", "HidHideCLI.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Nefarius Software Solutions", "HidHide", "x64", "HidHideCLI.exe")
            }.FirstOrDefault(File.Exists);
            if (cli == null) throw new FileNotFoundException("未找到 HidHideCLI.exe，请先运行 Install-Drivers.cmd。 ");
        }

        public void Activate()
        {
            originalCloak = Run("--cloak-state").Contains("--cloak-on");
            originalInverse = Run("--inv-state").Contains("--inv-on");
            originalApps = ParseRegistered(Run("--app-list"), "--app-reg");
            originalDevices = ParseRegistered(Run("--dev-list"), "--dev-hide");
            Run("--cloak-off"); Run("--inv-off");

            var apps = new[] {
                bridge,
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Flydigi Space Station", "Flydigi Space Station.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Flydigi Space Station", "SpaceStationService.exe")
            };
            foreach (var app in apps.Where(File.Exists))
                if (!originalApps.Contains(app)) { Run("--app-reg", app); addedApps.Add(app); }

            foreach (var instance in FindApexDevices())
                if (!originalDevices.Contains(instance)) { Run("--dev-hide", instance); addedDevices.Add(instance); }
            if (addedDevices.Count == 0 && !originalDevices.Any(d => d.IndexOf("VID_045E&PID_028E", StringComparison.OrdinalIgnoreCase) >= 0))
                throw new InvalidOperationException("未找到 APEX4 Xbox 360 Controller，请确认手柄处于 XInput 模式。");
            Run("--cloak-on");
        }

        public void Restore()
        {
            if (restored) return; restored = true;
            Run("--cloak-off");
            foreach (var device in addedDevices) TryRun("--dev-unhide", device);
            foreach (var app in addedApps) TryRun("--app-unreg", app);
            TryRun(originalInverse ? "--inv-on" : "--inv-off");
            TryRun(originalCloak ? "--cloak-on" : "--cloak-off");
        }

        private IEnumerable<string> FindApexDevices()
        {
            var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var parsed = new JavaScriptSerializer().DeserializeObject(Run("--dev-gaming")) as object[];
            if (parsed == null) return result;
            foreach (var groupObject in parsed)
            {
                var group = groupObject as Dictionary<string, object>;
                object devicesObject;
                if (group == null || !group.TryGetValue("devices", out devicesObject)) continue;
                var devices = devicesObject as object[];
                if (devices == null) continue;
                foreach (var deviceObject in devices)
                {
                    var device = deviceObject as Dictionary<string, object>;
                    if (device == null) continue;
                    var present = device.ContainsKey("present") && Convert.ToBoolean(device["present"]);
                    var basePath = device.ContainsKey("baseContainerDeviceInstancePath") ? Convert.ToString(device["baseContainerDeviceInstancePath"]) : "";
                    if (!present || basePath.IndexOf("USB\\VID_045E&PID_028E\\FLYDIGI_", StringComparison.OrdinalIgnoreCase) != 0) continue;
                    if (device.ContainsKey("deviceInstancePath")) result.Add(Convert.ToString(device["deviceInstancePath"]));
                    result.Add(basePath);
                }
            }
            return result;
        }

        private HashSet<string> ParseRegistered(string output, string prefix)
        {
            var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (Match match in Regex.Matches(output, "(?m)^" + Regex.Escape(prefix) + " \"(.*)\"$")) set.Add(match.Groups[1].Value);
            return set;
        }

        private string Run(params string[] args)
        {
            var info = new ProcessStartInfo(cli, string.Join(" ", args.Select(Quote))) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
            using (var process = Process.Start(info))
            {
                var output = process.StandardOutput.ReadToEnd(); var error = process.StandardError.ReadToEnd(); process.WaitForExit();
                if (process.ExitCode != 0) throw new InvalidOperationException("HidHide 命令失败：" + error);
                return output;
            }
        }

        private void TryRun(params string[] args) { try { Run(args); } catch { } }
        private static string Quote(string value) { return value.IndexOfAny(new[] { ' ', '\t', '"' }) >= 0 ? "\"" + value.Replace("\"", "\\\"") + "\"" : value; }
    }

    internal sealed class MiniSettings
    {
        public int Trigger = 100;
        public int Rumble = 100;
        public static MiniSettings Load(string path)
        {
            var result = new MiniSettings();
            try { if (File.Exists(path)) { var p = File.ReadAllText(path).Split(','); result.Trigger = Clamp(int.Parse(p[0])); result.Rumble = Clamp(int.Parse(p[1])); } } catch { }
            return result;
        }
        public static void Save(string path, int trigger, int rumble) { try { File.WriteAllText(path, trigger + "," + rumble); } catch { } }
        private static int Clamp(int value) { return Math.Max(0, Math.Min(200, value)); }
    }
}
