using Godot;
using System;
using System.Text.RegularExpressions;
using static Godot.GD;

namespace GodotRigidCharacter;

[Icon("res://addons/rigid_character/rigid_character/icons/rigid_character_2d.svg")]
public partial class RigidCharacter2D : CharacterBody2D
{
    public enum MotionBaseEnum { UpDirection, GlobalRotation };
    public enum MotionComponentEnum { X, Y };
    public enum UpDirectionBaseEnum { Default, GlobalRotation, ReversedGravityDirection };

    private double _mass = 1.0;
    private double _gravityScale = 1.0;
    private UpDirectionBaseEnum _upDirectionBase = UpDirectionBaseEnum.GlobalRotation;

    private Vector2 _prevVelocity = Vector2.Zero;
    private bool _prevWasOnFloor = false;
    private Vector2 _prevNormal = Vector2.Zero;

    protected double BodyDelta
    {
        get => Engine.IsInPhysicsFrame() ? GetPhysicsProcessDeltaTime() : GetProcessDeltaTime();
    }

    [Export(PropertyHint.Range, "0.0, 9999.9, 0.1, or_greater, hide_slider, suffix:kg")]
    public double Mass
    {
        get => _mass;
        set
        {
            _mass = value;
            PhysicsServer2D.BodySetParam(GetRid(), PhysicsServer2D.BodyParameter.Mass, _mass);
        }
    }
    [Export]
    public MotionBaseEnum MotionBase { get; set; } = MotionBaseEnum.UpDirection;
    [Export(PropertyHint.None, "suffix:px/s")]
    public Vector2 Motion
    {
        get
        {
            return MotionBase switch
            {
                MotionBaseEnum.UpDirection when MotionMode == MotionModeEnum.Grounded => Velocity.Rotated(UpDirectionRotation),
                MotionBaseEnum.GlobalRotation => Velocity.Rotated(GlobalRotation),
                _ => Velocity,
            };
        }
        set
        {
            if (MotionMode == MotionModeEnum.Floating)
            {
                Velocity = value;
                return;
            }

            switch (MotionBase)
            {
                case MotionBaseEnum.UpDirection:
                    Velocity = value.Rotated(-UpDirectionRotation);
                    break;
                case MotionBaseEnum.GlobalRotation:
                    Velocity = value.Rotated(-GlobalRotation);
                    break;
                default:
                    break;
            }
        }
    }
    [Export]
    public UpDirectionBaseEnum UpDirectionBase
    {
        get => _upDirectionBase;
        set
        {
            _upDirectionBase = value;
            UpdateUpDirection();
        }
    }

    [ExportGroup("Gravity")]
    [Export(PropertyHint.Range, "-8.0, 8.0, 0.1, or_greater, or_less")]
    public double GravityScale
    {
        get => _gravityScale;
        set
        {
            _gravityScale = value;
            PhysicsServer2D.BodySetParam(GetRid(), PhysicsServer2D.BodyParameter.GravityScale, _gravityScale);
        }
    }
    [Export(PropertyHint.Range, "0.0, 9999.9, 0.1, or_greater, hide_slider, suffix:px/s")]
    public double MaxFallingSpeed { get; set; } = 1500.0;

    [ExportGroup("Rotation Sync")]
    [Export]
    public bool RotationSyncEnabled { get; set; } = true;
    [Export(PropertyHint.Range, "0.0, 360.0, 0.1, or_greater, radians_as_degrees, suffix:°/s")]
    public double RotationSyncSpeed { get; set; } = Math.Tau;

    public double Momentum { get; set; }

    public float UpDirectionRotation
    {
        get => Vector2.Up.AngleTo(UpDirection);
    }
    public Vector2 PreviousVelocity
    {
        get => _prevVelocity;
    }

    private void UpdateUpDirection()
    {
        if (MotionMode == MotionModeEnum.Floating)
        {
            PrintErr("The property 'UpDirectionBase' can only be set when the motion mode is 'Grounded'.");
            return;
        }

        switch (_upDirectionBase)
        {
            case UpDirectionBaseEnum.GlobalRotation:
                UpDirection = Vector2.Up.Rotated(GlobalRotation);
                break;
            case UpDirectionBaseEnum.ReversedGravityDirection:
                UpDirection = -GetGravity().Normalized();
                break;
            default:
                break;
        }
    }

    protected virtual bool _Move(double scale)
    {
        _prevVelocity = Velocity;
        _prevWasOnFloor = IsOnFloor();

        var lastSlideCollision = GetLastSlideCollision();
        if (lastSlideCollision is not null)
            _prevNormal = lastSlideCollision.GetNormal();

        UpdateUpDirection(); // Triggers the setter to update the up direction.

        var g = GetGravity();
        var gdir = g.Normalized();

        if (!Mathf.IsZeroApprox(GravityScale))
        {
            Velocity += g * (float)GravityScale * (float)BodyDelta;

            var fallingVel = Velocity.Project(gdir);
            if (fallingVel.LengthSquared() > Math.Pow(MaxFallingSpeed, 2.0))
                Velocity += fallingVel.Normalized() * (float)MaxFallingSpeed - fallingVel;
        }

        SyncGlobalRotation();

        Velocity *= (float)scale;
        var ret = MoveAndSlide();
        Velocity /= (float)scale;

        return ret;
    }

    public void SyncGlobalRotation()
    {
        if (!RotationSyncEnabled) return;

        var gdr = PhysicsServer2D.AreaGetParam(GetViewport().FindWorld2D().Space, PhysicsServer2D.AreaParameter.GravityVector).As<Vector2>().AngleTo(GetGravity());
        var isRotationEqualApprox = Mathf.IsEqualApprox(GlobalRotation, gdr);

        if (GlobalRotation != gdr && (IsOnFloor() || _prevWasOnFloor || isRotationEqualApprox))
            GlobalRotation = gdr;
        else if (!isRotationEqualApprox)
            GlobalRotation = Mathf.Lerp(GlobalRotation, gdr, (float)RotationSyncSpeed * (float)BodyDelta);
    }

    public RigidCharacter2D()
    {
        Mass = _mass;
        GravityScale = _gravityScale;
    }
}