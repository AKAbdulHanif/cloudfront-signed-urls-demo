# Contributing to CloudFront Signed URLs Demo

Thank you for considering contributing to this project! 🎉

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (AWS region, Terraform version, etc.)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please create an issue with:
- Clear description of the enhancement
- Use case and benefits
- Possible implementation approach

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- **Terraform**: Follow [Terraform style guide](https://www.terraform.io/docs/language/syntax/style.html)
- **Python**: Follow [PEP 8](https://pep8.org/)
- **Documentation**: Use clear, concise language

### Testing

Before submitting a PR:
- Test Terraform changes with `terraform plan`
- Test Lambda function changes locally
- Run the test scripts in `scripts/` and `examples/`
- Update documentation if needed

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/cloudfront-signed-urls-demo.git
cd cloudfront-signed-urls-demo

# Create a branch
git checkout -b feature/my-feature

# Make changes and test
cd terraform
terraform init
terraform plan

# Build Lambda function
cd ../lambda
./build.sh

# Test
cd ../scripts
./test-api.sh
```

## Questions?

Feel free to open an issue for any questions!

